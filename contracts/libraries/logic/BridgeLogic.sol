// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { IERC20 } from "@interfaces/IERC20.sol";
import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";
import { SafeCast } from "@dependencies/SafeCast.sol";
import { IAToken } from "@interfaces/IAToken.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { UserConfiguration } from "@configuration/UserConfiguration.sol";
import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";
import { WadRayMath } from "@math/WadRayMath.sol";
import { PercentageMath } from "@math/PercentageMath.sol";
import { Errors } from "@helpers/Errors.sol";
import { ValidationLogic } from "@logic/ValidationLogic.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";

library BridgeLogic {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for uint256;
  using GPv2SafeERC20 for IERC20;

  function ps()
    internal
    pure
    returns (LibStorage.PoolStorage storage)
  {
    return LibStorage.poolStorage();
  }

  // See `IPool` for descriptions
  event ReserveUsedAsCollateralEnabled(
    address indexed reserve,
    address indexed user
  );
  event MintUnbacked(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );
  event BackUnbacked(
    address indexed reserve,
    address indexed backer,
    uint256 amount,
    uint256 fee
  );

  /**
   * @notice Mint unbacked aTokens to a user and updates the unbacked for the reserve.
   * @dev Essentially a supply without transferring the underlying.
   * @dev Emits the `MintUnbacked` event
   * @dev Emits the `ReserveUsedAsCollateralEnabled` if asset is set as collateral
   * @param asset The address of the underlying asset to mint aTokens of
   * @param amount The amount to mint
   * @param onBehalfOf The address that will receive the aTokens
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function executeMintUnbacked(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) internal {
    DataTypes.UserConfigurationMap storage userConfig = ps()
      .usersConfig[onBehalfOf];
    DataTypes.ReserveData storage reserve = ps().reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();

    reserve.updateState(reserveCache);

    ValidationLogic.validateSupply(reserveCache, amount);

    uint256 unbackedMintCap = reserveCache
      .reserveConfiguration
      .getUnbackedMintCap();
    uint256 reserveDecimals = reserveCache
      .reserveConfiguration
      .getDecimals();

    uint256 unbacked = reserve.unbacked += amount.toUint128();

    require(
      unbacked <= unbackedMintCap * (10**reserveDecimals),
      Errors.UNBACKED_MINT_CAP_EXCEEDED
    );

    reserve.updateInterestRates(reserveCache, asset, 0, 0);

    bool isFirstSupply = IAToken(reserveCache.aTokenAddress).mint(
      msg.sender,
      onBehalfOf,
      amount,
      reserveCache.nextLiquidityIndex
    );

    if (isFirstSupply) {
      if (
        ValidationLogic.validateUseAsCollateral(
          ps().reserves,
          ps().reservesList,
          userConfig,
          reserveCache.reserveConfiguration
        )
      ) {
        userConfig.setUsingAsCollateral(reserve.id, true);
        emit ReserveUsedAsCollateralEnabled(asset, onBehalfOf);
      }
    }

    emit MintUnbacked(
      asset,
      msg.sender,
      onBehalfOf,
      amount,
      referralCode
    );
  }

  /**
   * @notice Back the current unbacked with `amount` and pay `fee`.
   * @dev Emits the `BackUnbacked` event
   * @param asset The address of the underlying asset to repay
   * @param amount The amount to back
   * @param fee The amount paid in fees
   **/
  function executeBackUnbacked(
    address asset,
    uint256 amount,
    uint256 fee
  ) internal {
    DataTypes.ReserveData storage reserve = ps().reserves[asset];
    DataTypes.ReserveCache memory reserveCache = reserve.cache();
    uint256 protocolFeeBps = ps().bridgeProtocolFee;

    reserve.updateState(reserveCache);

    uint256 backingAmount = (amount < reserve.unbacked)
      ? amount
      : reserve.unbacked;

    uint256 feeToProtocol = fee.percentMul(protocolFeeBps);
    uint256 feeToLP = fee - feeToProtocol;
    uint256 added = backingAmount + fee;

    reserveCache.nextLiquidityIndex = reserve
      .cumulateToLiquidityIndex(
        IERC20(reserveCache.aTokenAddress).totalSupply(),
        feeToLP
      );

    reserve.accruedToTreasury += feeToProtocol
      .rayDiv(reserveCache.nextLiquidityIndex)
      .toUint128();

    reserve.unbacked -= backingAmount.toUint128();
    reserve.updateInterestRates(reserveCache, asset, added, 0);

    IERC20(asset).safeTransferFrom(
      msg.sender,
      reserveCache.aTokenAddress,
      added
    );

    emit BackUnbacked(asset, msg.sender, backingAmount, fee);
  }
}
