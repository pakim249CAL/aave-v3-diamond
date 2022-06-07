// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { BridgeLogic } from "@logic/BridgeLogic.sol";

contract BridgeEntry is Modifiers {
  function mintUnbacked(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external onlyBridge {
    BridgeLogic.executeMintUnbacked(
      asset,
      amount,
      onBehalfOf,
      referralCode
    );
  }

  function backUnbacked(
    address asset,
    uint256 amount,
    uint256 fee
  ) external onlyBridge {
    BridgeLogic.executeBackUnbacked(asset, amount, fee);
  }
}
