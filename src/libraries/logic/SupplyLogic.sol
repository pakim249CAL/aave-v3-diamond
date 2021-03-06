// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";
import { UserConfiguration } from "@configuration/UserConfiguration.sol";

import { IERC20 } from "@interfaces/IERC20.sol";

import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";

import { Errors } from "@helpers/Errors.sol";

import { DataTypes } from "@types/DataTypes.sol";

import { WadRayMath } from "@math/WadRayMath.sol";
import { PercentageMath } from "@math/PercentageMath.sol";

import { ValidationLogic } from "@logic/ValidationLogic.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";
import { MetaLogic } from "@logic/MetaLogic.sol";
import { TokenLogic } from "@logic/TokenLogic.sol";

/**
 * @title SupplyLogic library
 * @author Aave
 * @notice Implements the base logic for supply/withdraw
 */
library SupplyLogic {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using GPv2SafeERC20 for IERC20;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // See `IPool` for descriptions
  event ReserveUsedAsCollateralEnabled(
    address indexed reserve,
    address indexed user
  );
  event ReserveUsedAsCollateralDisabled(
    address indexed reserve,
    address indexed user
  );
  event Withdraw(
    address indexed reserve,
    address indexed user,
    address indexed to,
    uint256 amount
  );
  event Supply(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );

  function ps()
    internal
    pure
    returns (LibStorage.PoolStorage storage)
  {
    return LibStorage.poolStorage();
  }

  function ts()
    internal
    pure
    returns (LibStorage.TokenStorage storage)
  {
    return LibStorage.tokenStorage();
  }

  function msgSender() internal view returns (address) {
    return MetaLogic.msgSender();
  }

  /**
   * @notice Implements the supply feature. Through `supply()`, users supply assets to the Aave protocol.
   * @dev Emits the `Supply()` event.
   * @dev In the first supply action, `ReserveUsedAsCollateralEnabled()` is emitted, if the asset can be enabled as
   * collateral.
   * @param params The additional parameters needed to execute the supply function
   */
  function executeSupply(DataTypes.ExecuteSupplyParams memory params)
    internal
  {
    DataTypes.ReserveData storage reserve = ps().reserves[
      params.asset
    ];
    DataTypes.UserConfigurationMap storage userConfig = ps()
      .usersConfig[params.onBehalfOf];

    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    ValidationLogic.validateSupply(reserveCache, params.amount);

    reserve.updateInterestRates(
      reserveCache,
      params.asset,
      params.amount,
      0
    );

    IERC20(params.asset).safeTransferFrom(
      msgSender(),
      address(this),
      params.amount
    );

    bool isFirstSupply = TokenLogic.aTokenMint(
      params.onBehalfOf,
      reserve.id,
      params.amount,
      reserveCache.nextLiquidityIndex
    );

    if (isFirstSupply) {
      if (
        ValidationLogic.validateUseAsCollateral(
          userConfig,
          reserveCache.reserveConfiguration
        )
      ) {
        userConfig.setUsingAsCollateral(reserve.id, true);
        emit ReserveUsedAsCollateralEnabled(
          params.asset,
          params.onBehalfOf
        );
      }
    }

    emit Supply(
      params.asset,
      msgSender(),
      params.onBehalfOf,
      params.amount,
      params.referralCode
    );
  }

  /**
   * @notice Implements the withdraw feature. Through `withdraw()`, users redeem their aTokens for the underlying asset
   * previously supplied in the Aave protocol.
   * @dev Emits the `Withdraw()` event.
   * @dev If the user withdraws everything, `ReserveUsedAsCollateralDisabled()` is emitted.
   * @param params The additional parameters needed to execute the withdraw function
   * @return The actual amount withdrawn
   */
  function executeWithdraw(
    DataTypes.ExecuteWithdrawParams memory params
  ) internal returns (uint256) {
    DataTypes.UserConfigurationMap storage userConfig = ps()
      .usersConfig[msgSender()];

    DataTypes.ReserveData storage reserve = ps().reserves[
      params.asset
    ];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    uint256 userBalance = uint256(
      ts().aTokenBalances[reserveCache.id][msgSender()].balance
    ).rayMul(reserveCache.nextLiquidityIndex);

    uint256 amountToWithdraw = params.amount;

    if (params.amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }

    ValidationLogic.validateWithdraw(
      reserveCache,
      amountToWithdraw,
      userBalance
    );

    reserve.updateInterestRates(
      reserveCache,
      params.asset,
      0,
      amountToWithdraw
    );

    TokenLogic.aTokenBurn(
      msgSender(),
      params.to,
      reserveCache.id,
      amountToWithdraw,
      reserveCache.nextLiquidityIndex
    );

    if (userConfig.isUsingAsCollateral(reserve.id)) {
      if (userConfig.isBorrowingAny()) {
        ValidationLogic.validateHFAndLtv(
          ps().usersConfig[msgSender()],
          params.asset,
          msgSender(),
          ps().reservesCount,
          ps().usersEModeCategory[msgSender()]
        );
      }

      if (amountToWithdraw == userBalance) {
        userConfig.setUsingAsCollateral(reserve.id, false);
        emit ReserveUsedAsCollateralDisabled(
          params.asset,
          msgSender()
        );
      }
    }

    emit Withdraw(
      params.asset,
      msgSender(),
      params.to,
      amountToWithdraw
    );

    return amountToWithdraw;
  }

  /**
   * @notice Validates a transfer of aTokens. The sender is subjected to health factor validation to avoid
   * collateralization constraints violation.
   * @dev Emits the `ReserveUsedAsCollateralEnabled()` event for the `to` account, if the asset is being activated as
   * collateral.
   * @dev In case the `from` user transfers everything, `ReserveUsedAsCollateralDisabled()` is emitted for `from`.
   * @param params The additional parameters needed to execute the finalizeTransfer function
   */
  function executeFinalizeTransfer(
    DataTypes.FinalizeTransferParams memory params
  ) internal {
    DataTypes.ReserveData storage reserve = ps().reserves[
      params.asset
    ];

    ValidationLogic.validateTransfer(reserve);

    uint256 reserveId = reserve.id;

    if (params.from != params.to && params.amount != 0) {
      DataTypes.UserConfigurationMap storage fromConfig = ps()
        .usersConfig[params.from];

      if (fromConfig.isUsingAsCollateral(reserveId)) {
        if (fromConfig.isBorrowingAny()) {
          ValidationLogic.validateHFAndLtv(
            fromConfig,
            params.asset,
            params.from,
            ps().reservesCount,
            ps().usersEModeCategory[params.from]
          );
        }
        if (params.balanceFromBefore == params.amount) {
          fromConfig.setUsingAsCollateral(reserveId, false);
          emit ReserveUsedAsCollateralDisabled(
            params.asset,
            params.from
          );
        }
      }

      if (params.balanceToBefore == 0) {
        DataTypes.UserConfigurationMap storage toConfig = ps()
          .usersConfig[params.to];
        if (
          ValidationLogic.validateUseAsCollateral(
            toConfig,
            reserve.configuration
          )
        ) {
          toConfig.setUsingAsCollateral(reserveId, true);
          emit ReserveUsedAsCollateralEnabled(
            params.asset,
            params.to
          );
        }
      }
    }
  }

  /**
   * @notice Executes the 'set as collateral' feature. A user can choose to activate or deactivate an asset as
   * collateral at any point in time. Deactivating an asset as collateral is subjected to the usual health factor
   * checks to ensure collateralization.
   * @dev Emits the `ReserveUsedAsCollateralEnabled()` event if the asset can be activated as collateral.
   * @dev In case the asset is being deactivated as collateral, `ReserveUsedAsCollateralDisabled()` is emitted.
   * @param userConfig The users configuration mapping that track the supplied/borrowed assets
   * @param asset The address of the asset being configured as collateral
   * @param useAsCollateral True if the user wants to set the asset as collateral, false otherwise
   * @param userEModeCategory The eMode category chosen by the user
   */
  function executeUseReserveAsCollateral(
    DataTypes.UserConfigurationMap storage userConfig,
    address asset,
    bool useAsCollateral,
    uint8 userEModeCategory
  ) internal {
    DataTypes.ReserveData storage reserve = ps().reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    uint256 userBalance = TokenLogic.balanceOfAToken(
      reserveCache.id,
      msgSender()
    );

    ValidationLogic.validateSetUseReserveAsCollateral(
      reserveCache,
      userBalance
    );

    if (useAsCollateral == userConfig.isUsingAsCollateral(reserve.id))
      return;

    if (useAsCollateral) {
      require(
        ValidationLogic.validateUseAsCollateral(
          userConfig,
          reserveCache.reserveConfiguration
        ),
        Errors.USER_IN_ISOLATION_MODE
      );

      userConfig.setUsingAsCollateral(reserve.id, true);
      emit ReserveUsedAsCollateralEnabled(asset, msgSender());
    } else {
      userConfig.setUsingAsCollateral(reserve.id, false);
      ValidationLogic.validateHFAndLtv(
        userConfig,
        asset,
        msgSender(),
        ps().reservesCount,
        userEModeCategory
      );

      emit ReserveUsedAsCollateralDisabled(asset, msgSender());
    }
  }
}
