// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";
import { BridgeLogic } from "@logic/BridgeLogic.sol";
import { SupplyLogic } from "@logic/SupplyLogic.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

contract PoolFacet is Modifiers {
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

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) public {
    SupplyLogic.executeSupply(
      DataTypes.ExecuteSupplyParams({
        asset: asset,
        amount: amount,
        onBehalfOf: onBehalfOf,
        referralCode: referralCode
      })
    );
  }

  function supplyWithPermit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external {
    IERC20Permit(asset).permit(
      msg.sender,
      address(this),
      amount,
      deadline,
      permitV,
      permitR,
      permitS
    );
    SupplyLogic.executeSupply(
      DataTypes.ExecuteSupplyParams({
        asset: asset,
        amount: amount,
        onBehalfOf: onBehalfOf,
        referralCode: referralCode
      })
    );
  }

  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256) {
    return
      SupplyLogic.executeWithdraw(
        DataTypes.ExecuteWithdrawParams({
          asset: asset,
          amount: amount,
          to: to,
          reservesCount: ps().reservesCount,
          oracle: address(this), // TODO
          userEModeCategory: ps().usersEModeCategory[msg.sender]
        })
      );
  }
}
