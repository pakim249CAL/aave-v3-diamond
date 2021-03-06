// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";

import { IERC20 } from "@interfaces/IERC20.sol";

import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";

import { PercentageMath } from "@math/PercentageMath.sol";
import { WadRayMath } from "@math/WadRayMath.sol";

import { Helpers } from "@helpers/Helpers.sol";

import { DataTypes } from "@types/DataTypes.sol";

import { ReserveLogic } from "@logic/ReserveLogic.sol";
import { ValidationLogic } from "@logic/ValidationLogic.sol";
import { GenericLogic } from "@logic/GenericLogic.sol";
import { IsolationModeLogic } from "@logic/IsolationModeLogic.sol";
import { OracleLogic } from "@logic/OracleLogic.sol";
import { EModeLogic } from "@logic/EModeLogic.sol";
import { MetaLogic } from "@logic/MetaLogic.sol";
import { TokenLogic } from "@logic/TokenLogic.sol";

import { UserConfiguration } from "@configuration/UserConfiguration.sol";
import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";

/**
 * @title LiquidationLogic library
 * @author Aave
 * @notice Implements actions involving management of collateral in the protocol, the main one being the liquidations
 **/
library LiquidationLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using GPv2SafeERC20 for IERC20;

  // See `IPool` for descriptions
  event ReserveUsedAsCollateralEnabled(
    address indexed reserve,
    address indexed user
  );
  event ReserveUsedAsCollateralDisabled(
    address indexed reserve,
    address indexed user
  );
  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
  );

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

  /**
   * @dev Default percentage of borrower's debt to be repaid in a liquidation.
   * @dev Percentage applied when the users health factor is above `CLOSE_FACTOR_HF_THRESHOLD`
   * Expressed in bps, a value of 0.5e4 results in 50.00%
   */
  uint256 internal constant DEFAULT_LIQUIDATION_CLOSE_FACTOR = 0.5e4;

  /**
   * @dev Maximum percentage of borrower's debt to be repaid in a liquidation
   * @dev Percentage applied when the users health factor is below `CLOSE_FACTOR_HF_THRESHOLD`
   * Expressed in bps, a value of 1e4 results in 100.00%
   */
  uint256 internal constant MAX_LIQUIDATION_CLOSE_FACTOR = 1e4;

  /**
   * @dev This constant represents below which health factor value it is possible to liquidate
   * an amount of debt corresponding to `MAX_LIQUIDATION_CLOSE_FACTOR`.
   * A value of 0.95e18 results in 0.95
   */
  uint256 internal constant CLOSE_FACTOR_HF_THRESHOLD = 0.95e18;

  struct LiquidationCallLocalVars {
    uint256 userCollateralBalance;
    uint256 userVariableDebt;
    uint256 userTotalDebt;
    uint256 actualDebtToLiquidate;
    uint256 actualCollateralToLiquidate;
    uint256 liquidationBonus;
    uint256 healthFactor;
    uint256 liquidationProtocolFeeAmount;
    address collateralPriceSource;
    address debtPriceSource;
    DataTypes.ReserveCache debtReserveCache;
  }

  /**
   * @notice Function to liquidate a position if its Health Factor drops below 1. The caller (liquidator)
   * covers `debtToCover` amount of debt of the user getting liquidated, and receives
   * a proportional amount of the `collateralAsset` plus a bonus to cover market risk
   * @dev Emits the `LiquidationCall()` event
   * @param params The additional parameters needed to execute the liquidation function
   **/
  function executeLiquidationCall(
    DataTypes.ExecuteLiquidationCallParams memory params
  ) internal {
    LiquidationCallLocalVars memory vars;

    DataTypes.ReserveData storage collateralReserve = ps().reserves[
      params.collateralAsset
    ];
    DataTypes.ReserveData storage debtReserve = ps().reserves[
      params.debtAsset
    ];
    DataTypes.UserConfigurationMap storage userConfig = ps()
      .usersConfig[params.user];
    vars.debtReserveCache = debtReserve.cache();
    debtReserve.updateState(vars.debtReserveCache);

    (, , , , vars.healthFactor, ) = GenericLogic
      .calculateUserAccountData(
        DataTypes.CalculateUserAccountDataParams({
          userConfig: userConfig,
          reservesCount: params.reservesCount,
          user: params.user,
          userEModeCategory: params.userEModeCategory
        })
      );

    (
      vars.userVariableDebt,
      vars.userTotalDebt,
      vars.actualDebtToLiquidate
    ) = _calculateDebt(
      vars.debtReserveCache,
      params,
      vars.healthFactor
    );

    ValidationLogic.validateLiquidationCall(
      userConfig,
      collateralReserve,
      DataTypes.ValidateLiquidationCallParams({
        debtReserveCache: vars.debtReserveCache,
        totalDebt: vars.userTotalDebt,
        healthFactor: vars.healthFactor
      })
    );

    (
      vars.collateralPriceSource,
      vars.debtPriceSource,
      vars.liquidationBonus
    ) = _getConfigurationData(collateralReserve, params);

    vars.userCollateralBalance = TokenLogic.balanceOfAToken(
      collateralReserve.id,
      params.user
    );
    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = _calculateAvailableCollateralToLiquidate(
      collateralReserve,
      vars.debtReserveCache,
      vars.collateralPriceSource,
      vars.debtPriceSource,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.liquidationBonus
    );

    if (vars.userTotalDebt == vars.actualDebtToLiquidate) {
      userConfig.setBorrowing(debtReserve.id, false);
    }

    _burnDebtTokens(params, vars);

    debtReserve.updateInterestRates(
      vars.debtReserveCache,
      params.debtAsset,
      vars.actualDebtToLiquidate,
      0
    );

    IsolationModeLogic.updateIsolatedDebtIfIsolated(
      userConfig,
      vars.debtReserveCache,
      vars.actualDebtToLiquidate
    );

    if (params.receiveAToken) {
      _liquidateATokens(collateralReserve, params, vars);
    } else {
      _burnCollateralATokens(collateralReserve, params, vars);
    }

    // Transfer fee to treasury if it is non-zero
    if (vars.liquidationProtocolFeeAmount != 0) {
      TokenLogic.aTokenTransferFrom(
        params.user,
        ps().treasury,
        collateralReserve.id,
        vars.liquidationProtocolFeeAmount
      );
    }

    // If the collateral being liquidated is equal to the user balance,
    // we set the currency as not being used as collateral anymore
    if (
      vars.actualCollateralToLiquidate == vars.userCollateralBalance
    ) {
      userConfig.setUsingAsCollateral(collateralReserve.id, false);
      emit ReserveUsedAsCollateralDisabled(
        params.collateralAsset,
        params.user
      );
    }

    // Transfers the debt asset being repaid to the aToken, where the liquidity is kept
    IERC20(params.debtAsset).safeTransferFrom(
      msgSender(),
      address(this),
      vars.actualDebtToLiquidate
    );

    // IAToken(vars.debtReserveCache.aTokenAddress).handleRepayment(
    //   msgSender(),
    //   vars.actualDebtToLiquidate
    // );

    emit LiquidationCall(
      params.collateralAsset,
      params.debtAsset,
      params.user,
      vars.actualDebtToLiquidate,
      vars.actualCollateralToLiquidate,
      msgSender(),
      params.receiveAToken
    );
  }

  /**
   * @notice Burns the collateral aTokens and transfers the underlying to the liquidator.
   * @dev   The function also updates the state and the interest rate of the collateral reserve.
   * @param collateralReserve The data of the collateral reserve
   * @param params The additional parameters needed to execute the liquidation function
   * @param vars The executeLiquidationCall() function local vars
   */
  function _burnCollateralATokens(
    DataTypes.ReserveData storage collateralReserve,
    DataTypes.ExecuteLiquidationCallParams memory params,
    LiquidationCallLocalVars memory vars
  ) internal {
    DataTypes.ReserveCache
      memory collateralReserveCache = collateralReserve.cache();
    collateralReserve.updateState(collateralReserveCache);
    collateralReserve.updateInterestRates(
      collateralReserveCache,
      params.collateralAsset,
      0,
      vars.actualCollateralToLiquidate
    );

    // Burn the equivalent amount of aToken, sending the underlying to the liquidator
    TokenLogic.aTokenBurn(
      params.user,
      msgSender(),
      collateralReserveCache.id,
      vars.actualCollateralToLiquidate,
      collateralReserveCache.nextLiquidityIndex
    );
  }

  /**
   * @notice Liquidates the user aTokens by transferring them to the liquidator.
   * @dev   The function also checks the state of the liquidator and activates the aToken as collateral
   *        as in standard transfers if the isolation mode constraints are respected.
   * @param collateralReserve The data of the collateral reserve
   * @param params The additional parameters needed to execute the liquidation function
   * @param vars The executeLiquidationCall() function local vars
   */
  function _liquidateATokens(
    DataTypes.ReserveData storage collateralReserve,
    DataTypes.ExecuteLiquidationCallParams memory params,
    LiquidationCallLocalVars memory vars
  ) internal {
    uint256 liquidatorPreviousATokenBalance = TokenLogic
      .balanceOfAToken(collateralReserve.id, msgSender());
    TokenLogic.aTokenTransferFrom(
      params.user,
      msgSender(),
      collateralReserve.id,
      vars.actualCollateralToLiquidate
    );

    if (liquidatorPreviousATokenBalance == 0) {
      DataTypes.UserConfigurationMap storage liquidatorConfig = ps()
        .usersConfig[msgSender()];
      if (
        ValidationLogic.validateUseAsCollateral(
          liquidatorConfig,
          collateralReserve.configuration
        )
      ) {
        liquidatorConfig.setUsingAsCollateral(
          collateralReserve.id,
          true
        );
        emit ReserveUsedAsCollateralEnabled(
          params.collateralAsset,
          msgSender()
        );
      }
    }
  }

  /**
   * @notice Burns the debt tokens of the user up to the amount being repaid by the liquidator.
   * @dev The function alters the `debtReserveCache` state in `vars` to update the debt related data.
   * @param params The additional parameters needed to execute the liquidation function
   * @param vars the executeLiquidationCall() function local vars
   */
  function _burnDebtTokens(
    DataTypes.ExecuteLiquidationCallParams memory params,
    LiquidationCallLocalVars memory vars
  ) internal {
    if (vars.userVariableDebt >= vars.actualDebtToLiquidate) {
      vars.debtReserveCache.nextScaledVariableDebt = TokenLogic
        .variableDebtTokenBurn(
          params.user,
          ps().reserves[params.debtAsset].id,
          vars.actualDebtToLiquidate,
          vars.debtReserveCache.nextVariableBorrowIndex
        );
    } else {
      // If the user doesn't have variable debt, no need to try to burn variable debt tokens
      if (vars.userVariableDebt != 0) {
        vars.debtReserveCache.nextScaledVariableDebt = TokenLogic
          .variableDebtTokenBurn(
            params.user,
            ps().reserves[params.debtAsset].id,
            vars.userVariableDebt,
            vars.debtReserveCache.nextVariableBorrowIndex
          );
      }
      (
        vars.debtReserveCache.nextTotalStableDebt,
        vars.debtReserveCache.nextAvgStableBorrowRate
      ) = TokenLogic.stableDebtTokenBurn(
        params.user,
        ps().reserves[params.debtAsset].id,
        vars.actualDebtToLiquidate - vars.userVariableDebt
      );
    }
  }

  /**
   * @notice Calculates the total debt of the user and the actual amount to liquidate depending on the health factor
   * and corresponding close factor.
   * @dev If the Health Factor is below CLOSE_FACTOR_HF_THRESHOLD, the close factor is increased to MAX_LIQUIDATION_CLOSE_FACTOR
   * @param debtReserveCache The reserve cache data object of the debt reserve
   * @param params The additional parameters needed to execute the liquidation function
   * @param healthFactor The health factor of the position
   * @return The variable debt of the user
   * @return The total debt of the user
   * @return The actual debt to liquidate as a function of the closeFactor
   */
  function _calculateDebt(
    DataTypes.ReserveCache memory debtReserveCache,
    DataTypes.ExecuteLiquidationCallParams memory params,
    uint256 healthFactor
  )
    internal
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    (uint256 userStableDebt, uint256 userVariableDebt) = Helpers
      .getUserCurrentDebt(params.user, debtReserveCache);

    uint256 userTotalDebt = userStableDebt + userVariableDebt;

    uint256 closeFactor = healthFactor > CLOSE_FACTOR_HF_THRESHOLD
      ? DEFAULT_LIQUIDATION_CLOSE_FACTOR
      : MAX_LIQUIDATION_CLOSE_FACTOR;

    uint256 maxLiquidatableDebt = userTotalDebt.percentMul(
      closeFactor
    );

    uint256 actualDebtToLiquidate = params.debtToCover >
      maxLiquidatableDebt
      ? maxLiquidatableDebt
      : params.debtToCover;

    return (userVariableDebt, userTotalDebt, actualDebtToLiquidate);
  }

  /**
   * @notice Returns the configuration data for the debt and the collateral reserves.
   * @param collateralReserve The data of the collateral reserve
   * @param params The additional parameters needed to execute the liquidation function
   * @return The address to use as price source for the collateral
   * @return The address to use as price source for the debt
   * @return The liquidation bonus to apply to the collateral
   */
  function _getConfigurationData(
    DataTypes.ReserveData storage collateralReserve,
    DataTypes.ExecuteLiquidationCallParams memory params
  )
    internal
    view
    returns (
      address,
      address,
      uint256
    )
  {
    uint256 liquidationBonus = collateralReserve
      .configuration
      .getLiquidationBonus();

    address collateralPriceSource = params.collateralAsset;
    address debtPriceSource = params.debtAsset;

    if (params.userEModeCategory != 0) {
      if (
        EModeLogic.isInEModeCategory(
          params.userEModeCategory,
          collateralReserve.configuration.getEModeCategory()
        )
      ) {
        liquidationBonus = ps()
          .eModeCategories[params.userEModeCategory]
          .liquidationBonus;
      }
    }

    return (collateralPriceSource, debtPriceSource, liquidationBonus);
  }

  struct AvailableCollateralToLiquidateLocalVars {
    uint256 collateralPrice;
    uint256 debtAssetPrice;
    uint256 maxCollateralToLiquidate;
    uint256 baseCollateral;
    uint256 bonusCollateral;
    uint256 debtAssetDecimals;
    uint256 collateralDecimals;
    uint256 collateralAssetUnit;
    uint256 debtAssetUnit;
    uint256 collateralAmount;
    uint256 debtAmountNeeded;
    uint256 liquidationProtocolFeePercentage;
    uint256 liquidationProtocolFee;
  }

  /**
   * @notice Calculates how much of a specific collateral can be liquidated, given
   * a certain amount of debt asset.
   * @dev This function needs to be called after all the checks to validate the liquidation have been performed,
   *   otherwise it might fail.
   * @param collateralReserve The data of the collateral reserve
   * @param debtReserveCache The cached data of the debt reserve
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param userCollateralBalance The collateral balance for the specific `collateralAsset` of the user being liquidated
   * @param liquidationBonus The collateral bonus percentage to receive as result of the liquidation
   * @return The maximum amount that is possible to liquidate given all the liquidation constraints (user balance, close factor)
   * @return The amount to repay with the liquidation
   * @return The fee taken from the liquidation bonus amount to be paid to the protocol
   **/
  function _calculateAvailableCollateralToLiquidate(
    DataTypes.ReserveData storage collateralReserve,
    DataTypes.ReserveCache memory debtReserveCache,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    uint256 userCollateralBalance,
    uint256 liquidationBonus
  )
    internal
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    AvailableCollateralToLiquidateLocalVars memory vars;

    vars.collateralPrice = OracleLogic.getAssetPrice(collateralAsset);
    vars.debtAssetPrice = OracleLogic.getAssetPrice(debtAsset);

    vars.collateralDecimals = collateralReserve
      .configuration
      .getDecimals();
    vars.debtAssetDecimals = debtReserveCache
      .reserveConfiguration
      .getDecimals();

    unchecked {
      vars.collateralAssetUnit = 10**vars.collateralDecimals;
      vars.debtAssetUnit = 10**vars.debtAssetDecimals;
    }

    vars.liquidationProtocolFeePercentage = collateralReserve
      .configuration
      .getLiquidationProtocolFee();

    // This is the base collateral to liquidate based on the given debt to cover
    vars.baseCollateral =
      (
        (vars.debtAssetPrice * debtToCover * vars.collateralAssetUnit)
      ) /
      (vars.collateralPrice * vars.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(
      liquidationBonus
    );

    if (vars.maxCollateralToLiquidate > userCollateralBalance) {
      vars.collateralAmount = userCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralPrice *
        vars.collateralAmount *
        vars.debtAssetUnit) /
        (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(
          liquidationBonus
        );
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = debtToCover;
    }

    if (vars.liquidationProtocolFeePercentage != 0) {
      vars.bonusCollateral =
        vars.collateralAmount -
        vars.collateralAmount.percentDiv(liquidationBonus);

      vars.liquidationProtocolFee = vars.bonusCollateral.percentMul(
        vars.liquidationProtocolFeePercentage
      );

      return (
        vars.collateralAmount - vars.liquidationProtocolFee,
        vars.debtAmountNeeded,
        vars.liquidationProtocolFee
      );
    } else {
      return (vars.collateralAmount, vars.debtAmountNeeded, 0);
    }
  }
}
