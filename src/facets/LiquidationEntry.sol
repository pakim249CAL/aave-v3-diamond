// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { DataTypes } from "@types/DataTypes.sol";

import { LiquidationLogic } from "@logic/LiquidationLogic.sol";

contract LiquidationEntry is Modifiers {
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) external {
    LiquidationLogic.executeLiquidationCall(
      DataTypes.ExecuteLiquidationCallParams({
        reservesCount: ps().reservesCount,
        debtToCover: debtToCover,
        collateralAsset: collateralAsset,
        debtAsset: debtAsset,
        user: user,
        receiveAToken: receiveAToken,
        userEModeCategory: ps().usersEModeCategory[user]
      })
    );
  }
}
