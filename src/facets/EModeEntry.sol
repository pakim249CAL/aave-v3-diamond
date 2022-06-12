// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { EModeLogic } from "@logic/EModeLogic.sol";

import { DataTypes } from "@types/DataTypes.sol";

contract EModeEntry is Modifiers {
  function setUserEMode(uint8 categoryId) external {
    EModeLogic.executeSetUserEMode(
      ps().usersConfig[msgSender()],
      DataTypes.ExecuteSetUserEModeParams({
        reservesCount: ps().reservesCount,
        categoryId: categoryId
      })
    );
  }
}
