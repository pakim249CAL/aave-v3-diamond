// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";

import { DataTypes } from "@types/DataTypes.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";
import { UserConfiguration } from "@configuration/UserConfiguration.sol";

import { SafeCast } from "@dependencies/SafeCast.sol";

/**
 * @title IsolationModeLogic library
 * @author Aave
 * @notice Implements the base logic for handling repayments for assets borrowed in isolation mode
 */
library IsolationModeLogic {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using SafeCast for uint256;

  // See `IPool` for descriptions
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
   * @notice updated the isolated debt whenever a position collateralized by an isolated asset is repaid or liquidated
   * @param userConfig The user configuration mapping
   * @param reserveCache The cached data of the reserve
   * @param repayAmount The amount being repaid
   */
  function updateIsolatedDebtIfIsolated(
    DataTypes.UserConfigurationMap storage userConfig,
    DataTypes.ReserveCache memory reserveCache,
    uint256 repayAmount
  ) internal {
    (
      bool isolationModeActive,
      address isolationModeCollateralAddress,

    ) = userConfig.getIsolationModeState();

    if (isolationModeActive) {
      uint128 isolationModeTotalDebt = ps()
        .reserves[isolationModeCollateralAddress]
        .isolationModeTotalDebt;

      uint128 isolatedDebtRepaid = (repayAmount /
        10 **
          (reserveCache.reserveConfiguration.getDecimals() -
            ReserveConfiguration.DEBT_CEILING_DECIMALS)).toUint128();

      // since the debt ceiling does not take into account the interest accrued, it might happen that amount
      // repaid > debt in isolation mode
      if (isolationModeTotalDebt <= isolatedDebtRepaid) {
        ps()
          .reserves[isolationModeCollateralAddress]
          .isolationModeTotalDebt = 0;
        emit IsolationModeTotalDebtUpdated(
          isolationModeCollateralAddress,
          0
        );
      } else {
        uint256 nextIsolationModeTotalDebt = ps()
          .reserves[isolationModeCollateralAddress]
          .isolationModeTotalDebt =
          isolationModeTotalDebt -
          isolatedDebtRepaid;
        emit IsolationModeTotalDebtUpdated(
          isolationModeCollateralAddress,
          nextIsolationModeTotalDebt
        );
      }
    }
  }
}
