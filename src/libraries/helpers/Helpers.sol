// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { IERC20 } from "@interfaces/IERC20.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { TokenLogic } from "@logic/TokenLogic.sol";

/**
 * @title Helpers library
 * @author Aave
 */
library Helpers {
  /**
   * @notice Fetches the user current stable and variable debt balances
   * @param user The user address
   * @param reserveCache The reserve cache data object
   * @return The stable debt balance
   * @return The variable debt balance
   **/
  function getUserCurrentDebt(
    address user,
    DataTypes.ReserveCache memory reserveCache
  ) internal view returns (uint256, uint256) {
    return (
      TokenLogic.balanceOfStableDebt(reserveCache.id, user),
      TokenLogic.balanceOfVariableDebt(reserveCache.id, user)
    );
  }
}
