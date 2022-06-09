// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";
import { SafeCast } from "@dependencies/SafeCast.sol";
import { IERC20 } from "@interfaces/IERC20.sol";
import { IStableDebtToken } from "@interfaces/IStableDebtToken.sol";
import { IVariableDebtToken } from "@interfaces/IVariableDebtToken.sol";
import { IAToken } from "@interfaces/IAToken.sol";
import { UserConfiguration } from "@configuration/UserConfiguration.sol";
import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";
import { Helpers } from "@helpers/Helpers.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { ValidationLogic } from "@logic/ValidationLogic.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";
import { IsolationModeLogic } from "@logic/IsolationModeLogic.sol";
import { MetaLogic } from "@logic/MetaLogic.sol";

/**
 * @title BorrowLogic library
 * @author Aave
 * @notice Implements the base logic for all the actions related to borrowing
 */
library BorrowLogic {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using GPv2SafeERC20 for IERC20;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using SafeCast for uint256;

  function ps()
    internal
    pure
    returns (LibStorage.PoolStorage storage)
  {
    return LibStorage.poolStorage();
  }

  function msgSender() internal view returns (address) {
    return MetaLogic.msgSender();
  }

  // See `IPool` for descriptions
  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    DataTypes.InterestRateMode interestRateMode,
    uint256 borrowRate,
    uint16 indexed referralCode
  );
  event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount,
    bool useATokens
  );
  event RebalanceStableBorrowRate(
    address indexed reserve,
    address indexed user
  );
  event SwapBorrowRateMode(
    address indexed reserve,
    address indexed user,
    DataTypes.InterestRateMode interestRateMode
  );
  event IsolationModeTotalDebtUpdated(
    address indexed asset,
    uint256 totalDebt
  );

  /**
   * @notice Implements the borrow feature. Borrowing allows users that provided collateral to draw liquidity from the
   * Aave protocol proportionally to their collateralization power. For isolated positions, it also increases the
   * isolated debt.
   * @dev  Emits the `Borrow()` event
   * @param params The additional parameters needed to execute the borrow function
   */
  function executeBorrow(DataTypes.ExecuteBorrowParams memory params)
    internal
  {
    DataTypes.ReserveData storage reserve = ps().reserves[
      params.asset
    ];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    (
      bool isolationModeActive,
      address isolationModeCollateralAddress,
      uint256 isolationModeDebtCeiling
    ) = ps().usersConfig[params.onBehalfOf].getIsolationModeState();

    ValidationLogic.validateBorrow(
      DataTypes.ValidateBorrowParams({
        reserveCache: reserveCache,
        userConfig: ps().usersConfig[params.onBehalfOf],
        asset: params.asset,
        userAddress: params.onBehalfOf,
        amount: params.amount,
        interestRateMode: params.interestRateMode,
        maxStableLoanPercent: params.maxStableRateBorrowSizePercent,
        reservesCount: params.reservesCount,
        userEModeCategory: params.userEModeCategory,
        isolationModeActive: isolationModeActive,
        isolationModeCollateralAddress: isolationModeCollateralAddress,
        isolationModeDebtCeiling: isolationModeDebtCeiling
      })
    );

    uint256 currentStableRate = 0;
    bool isFirstBorrowing = false;

    if (
      params.interestRateMode == DataTypes.InterestRateMode.STABLE
    ) {
      currentStableRate = reserve.currentStableBorrowRate;

      (
        isFirstBorrowing,
        reserveCache.nextTotalStableDebt,
        reserveCache.nextAvgStableBorrowRate
      ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).mint(
        params.user,
        params.onBehalfOf,
        params.amount,
        currentStableRate
      );
    } else {
      (
        isFirstBorrowing,
        reserveCache.nextScaledVariableDebt
      ) = IVariableDebtToken(reserveCache.variableDebtTokenAddress)
        .mint(
          params.user,
          params.onBehalfOf,
          params.amount,
          reserveCache.nextVariableBorrowIndex
        );
    }

    if (isFirstBorrowing) {
      ps().usersConfig[params.onBehalfOf].setBorrowing(
        reserve.id,
        true
      );
    }

    if (isolationModeActive) {
      uint256 nextIsolationModeTotalDebt = ps()
        .reserves[isolationModeCollateralAddress]
        .isolationModeTotalDebt += (params.amount /
        10 **
          (reserveCache.reserveConfiguration.getDecimals() -
            ReserveConfiguration.DEBT_CEILING_DECIMALS)).toUint128();
      emit IsolationModeTotalDebtUpdated(
        isolationModeCollateralAddress,
        nextIsolationModeTotalDebt
      );
    }

    reserve.updateInterestRates(
      reserveCache,
      params.asset,
      0,
      params.releaseUnderlying ? params.amount : 0
    );

    if (params.releaseUnderlying) {
      IAToken(reserveCache.aTokenAddress).transferUnderlyingTo(
        params.user,
        params.amount
      );
    }

    emit Borrow(
      params.asset,
      params.user,
      params.onBehalfOf,
      params.amount,
      params.interestRateMode,
      params.interestRateMode == DataTypes.InterestRateMode.STABLE
        ? currentStableRate
        : reserve.currentVariableBorrowRate,
      params.referralCode
    );
  }

  /**
   * @notice Implements the repay feature. Repaying transfers the underlying back to the aToken and clears the
   * equivalent amount of debt for the user by burning the corresponding debt token. For isolated positions, it also
   * reduces the isolated debt.
   * @dev  Emits the `Repay()` event
   * @param params The additional parameters needed to execute the repay function
   * @return The actual amount being repaid
   */
  function executeRepay(DataTypes.ExecuteRepayParams memory params)
    internal
    returns (uint256)
  {
    DataTypes.ReserveData storage reserve = ps().reserves[
      params.asset
    ];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();
    reserve.updateState(reserveCache);

    (uint256 stableDebt, uint256 variableDebt) = Helpers
      .getUserCurrentDebt(params.onBehalfOf, reserveCache);

    ValidationLogic.validateRepay(
      reserveCache,
      params.amount,
      params.interestRateMode,
      params.onBehalfOf,
      stableDebt,
      variableDebt
    );

    uint256 paybackAmount = params.interestRateMode ==
      DataTypes.InterestRateMode.STABLE
      ? stableDebt
      : variableDebt;

    // Allows a user to repay with aTokens without leaving dust from interest.
    if (params.useATokens && params.amount == type(uint256).max) {
      params.amount = IAToken(reserveCache.aTokenAddress).balanceOf(
        msgSender()
      );
    }

    if (params.amount < paybackAmount) {
      paybackAmount = params.amount;
    }

    if (
      params.interestRateMode == DataTypes.InterestRateMode.STABLE
    ) {
      (
        reserveCache.nextTotalStableDebt,
        reserveCache.nextAvgStableBorrowRate
      ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).burn(
        params.onBehalfOf,
        paybackAmount
      );
    } else {
      reserveCache.nextScaledVariableDebt = IVariableDebtToken(
        reserveCache.variableDebtTokenAddress
      ).burn(
          params.onBehalfOf,
          paybackAmount,
          reserveCache.nextVariableBorrowIndex
        );
    }

    reserve.updateInterestRates(
      reserveCache,
      params.asset,
      params.useATokens ? 0 : paybackAmount,
      0
    );

    if (stableDebt + variableDebt - paybackAmount == 0) {
      ps().usersConfig[params.onBehalfOf].setBorrowing(
        reserve.id,
        false
      );
    }

    IsolationModeLogic.updateIsolatedDebtIfIsolated(
      ps().usersConfig[params.onBehalfOf],
      reserveCache,
      paybackAmount
    );

    if (params.useATokens) {
      IAToken(reserveCache.aTokenAddress).burn(
        msgSender(),
        reserveCache.aTokenAddress,
        paybackAmount,
        reserveCache.nextLiquidityIndex
      );
    } else {
      IERC20(params.asset).safeTransferFrom(
        msgSender(),
        reserveCache.aTokenAddress,
        paybackAmount
      );
      IAToken(reserveCache.aTokenAddress).handleRepayment(
        msgSender(),
        paybackAmount
      );
    }

    emit Repay(
      params.asset,
      params.onBehalfOf,
      msgSender(),
      paybackAmount,
      params.useATokens
    );

    return paybackAmount;
  }

  /**
   * @notice Implements the rebalance stable borrow rate feature. In case of liquidity crunches on the protocol, stable
   * rate borrows might need to be rebalanced to bring back equilibrium between the borrow and supply APYs.
   * @dev The rules that define if a position can be rebalanced are implemented in `ValidationLogic.validateRebalanceStableBorrowRate()`
   * @dev Emits the `RebalanceStableBorrowRate()` event
   * @param asset The asset of the position being rebalanced
   * @param user The user being rebalanced
   */
  function executeRebalanceStableBorrowRate(
    address asset,
    address user
  ) internal {
    DataTypes.ReserveData storage reserve = ps().reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();
    reserve.updateState(reserveCache);

    ValidationLogic.validateRebalanceStableBorrowRate(
      reserve,
      reserveCache,
      asset
    );

    IStableDebtToken stableDebtToken = IStableDebtToken(
      reserveCache.stableDebtTokenAddress
    );
    uint256 stableDebt = IERC20(address(stableDebtToken)).balanceOf(
      user
    );

    stableDebtToken.burn(user, stableDebt);

    (
      ,
      reserveCache.nextTotalStableDebt,
      reserveCache.nextAvgStableBorrowRate
    ) = stableDebtToken.mint(
      user,
      user,
      stableDebt,
      reserve.currentStableBorrowRate
    );

    reserve.updateInterestRates(reserveCache, asset, 0, 0);

    emit RebalanceStableBorrowRate(asset, user);
  }

  /**
   * @notice Implements the swap borrow rate feature. Borrowers can swap from variable to stable positions at any time.
   * @dev Emits the `Swap()` event
   * @param userConfig The user configuration mapping that tracks the supplied/borrowed assets
   * @param asset The asset of the position being swapped
   * @param interestRateMode The current interest rate mode of the position being swapped
   */
  function executeSwapBorrowRateMode(
    DataTypes.UserConfigurationMap storage userConfig,
    address asset,
    DataTypes.InterestRateMode interestRateMode
  ) internal {
    DataTypes.ReserveData storage reserve = ps().reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    (uint256 stableDebt, uint256 variableDebt) = Helpers
      .getUserCurrentDebt(msgSender(), reserveCache);

    ValidationLogic.validateSwapRateMode(
      reserve,
      reserveCache,
      userConfig,
      stableDebt,
      variableDebt,
      interestRateMode
    );

    if (interestRateMode == DataTypes.InterestRateMode.STABLE) {
      (
        reserveCache.nextTotalStableDebt,
        reserveCache.nextAvgStableBorrowRate
      ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).burn(
        msgSender(),
        stableDebt
      );

      (, reserveCache.nextScaledVariableDebt) = IVariableDebtToken(
        reserveCache.variableDebtTokenAddress
      ).mint(
          msgSender(),
          msgSender(),
          stableDebt,
          reserveCache.nextVariableBorrowIndex
        );
    } else {
      reserveCache.nextScaledVariableDebt = IVariableDebtToken(
        reserveCache.variableDebtTokenAddress
      ).burn(
          msgSender(),
          variableDebt,
          reserveCache.nextVariableBorrowIndex
        );

      (
        ,
        reserveCache.nextTotalStableDebt,
        reserveCache.nextAvgStableBorrowRate
      ) = IStableDebtToken(reserveCache.stableDebtTokenAddress).mint(
        msgSender(),
        msgSender(),
        variableDebt,
        reserve.currentStableBorrowRate
      );
    }

    reserve.updateInterestRates(reserveCache, asset, 0, 0);

    emit SwapBorrowRateMode(asset, msgSender(), interestRateMode);
  }
}
