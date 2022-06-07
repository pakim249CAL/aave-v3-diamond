// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";
import { Address } from "@dependencies/Address.sol";
import { IERC20 } from "@interfaces/IERC20.sol";
import { IAToken } from "@interfaces/IAToken.sol";
import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";
import { Errors } from "@helpers/Errors.sol";
import { WadRayMath } from "@math/WadRayMath.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";
import { ValidationLogic } from "@logic/ValidationLogic.sol";
import { GenericLogic } from "@logic/GenericLogic.sol";

/**
 * @title PoolLogic library
 * @author Aave
 * @notice Implements the logic for Pool specific functions
 */
library PoolLogic {
  using GPv2SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using ReserveLogic for DataTypes.ReserveData;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  // See `IPool` for descriptions
  event MintedToTreasury(
    address indexed reserve,
    uint256 amountMinted
  );
  event IsolationModeTotalDebtUpdated(
    address indexed asset,
    uint256 totalDebt
  );

  function ps()
    internal
    pure
    returns (LibStorage.PoolStorage storage)
  {
    return LibStorage.poolStorage();
  }

  /**
   * @notice Initialize an asset reserve and add the reserve to the list of reserves
   * @param params Additional parameters needed for initiation
   * @return true if appended, false if inserted at existing empty spot
   **/
  function executeInitReserve(
    DataTypes.InitReserveParams memory params
  ) internal returns (bool) {
    require(Address.isContract(params.asset), Errors.NOT_CONTRACT);
    ps().reserves[params.asset].init(
      params.aTokenAddress,
      params.stableDebtAddress,
      params.variableDebtAddress,
      params.interestRateStrategyAddress
    );

    bool reserveAlreadyAdded = ps().reserves[params.asset].id != 0 ||
      ps().reservesList[0] == params.asset;
    require(!reserveAlreadyAdded, Errors.RESERVE_ALREADY_ADDED);

    for (uint16 i = 0; i < params.reservesCount; i++) {
      if (ps().reservesList[i] == address(0)) {
        ps().reserves[params.asset].id = i;
        ps().reservesList[i] = params.asset;
        return false;
      }
    }

    require(
      params.reservesCount < params.maxNumberReserves,
      Errors.NO_MORE_RESERVES_ALLOWED
    );
    ps().reserves[params.asset].id = params.reservesCount;
    ps().reservesList[params.reservesCount] = params.asset;
    return true;
  }

  /**
   * @notice Rescue and transfer tokens locked in this contract
   * @param token The address of the token
   * @param to The address of the recipient
   * @param amount The amount of token to transfer
   */
  function executeRescueTokens(
    address token,
    address to,
    uint256 amount
  ) internal {
    IERC20(token).safeTransfer(to, amount);
  }

  /**
   * @notice Mints the assets accrued through the reserve factor to the treasury in the form of aTokens
   * @param assets The list of reserves for which the minting needs to be executed
   **/
  function executeMintToTreasury(address[] calldata assets) internal {
    for (uint256 i = 0; i < assets.length; i++) {
      address assetAddress = assets[i];

      DataTypes.ReserveData storage reserve = ps().reserves[
        assetAddress
      ];

      // this cover both inactive reserves and invalid reserves since the flag will be 0 for both
      if (!reserve.configuration.getActive()) {
        continue;
      }

      uint256 accruedToTreasury = reserve.accruedToTreasury;

      if (accruedToTreasury != 0) {
        reserve.accruedToTreasury = 0;
        uint256 normalizedIncome = reserve.getNormalizedIncome();
        uint256 amountToMint = accruedToTreasury.rayMul(
          normalizedIncome
        );
        IAToken(reserve.aTokenAddress).mintToTreasury(
          amountToMint,
          normalizedIncome
        );

        emit MintedToTreasury(assetAddress, amountToMint);
      }
    }
  }

  /**
   * @notice Resets the isolation mode total debt of the given asset to zero
   * @dev It requires the given asset has zero debt ceiling
   * @param asset The address of the underlying asset to reset the isolationModeTotalDebt
   */
  function executeResetIsolationModeTotalDebt(address asset)
    internal
  {
    require(
      ps().reserves[asset].configuration.getDebtCeiling() == 0,
      Errors.DEBT_CEILING_NOT_ZERO
    );
    ps().reserves[asset].isolationModeTotalDebt = 0;
    emit IsolationModeTotalDebtUpdated(asset, 0);
  }

  /**
   * @notice Drop a reserve
   * @param asset The address of the underlying asset of the reserve
   **/
  function executeDropReserve(address asset) internal {
    ValidationLogic.validateDropReserve(asset);
    ps().reservesList[ps().reserves[asset].id] = address(0);
    delete ps().reserves[asset];
  }

  /**
   * @notice Returns the user account data across all the reserves
   * @param params Additional params needed for the calculation
   * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
   * @return totalDebtBase The total debt of the user in the base currency used by the price feed
   * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
   * @return currentLiquidationThreshold The liquidation threshold of the user
   * @return ltv The loan to value of The user
   * @return healthFactor The current health factor of the user
   **/
  function executeGetUserAccountData(
    DataTypes.CalculateUserAccountDataParams memory params
  )
    internal
    view
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    )
  {
    (
      totalCollateralBase,
      totalDebtBase,
      ltv,
      currentLiquidationThreshold,
      healthFactor,

    ) = GenericLogic.calculateUserAccountData(params);

    availableBorrowsBase = GenericLogic.calculateAvailableBorrows(
      totalCollateralBase,
      totalDebtBase,
      ltv
    );
  }
}
