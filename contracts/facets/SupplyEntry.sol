// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { SupplyLogic } from "@logic/SupplyLogic.sol";

import { Errors } from "@helpers/Errors.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

contract SupplyEntry is Modifiers {
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
      msgSender(),
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
          to: to
        })
      );
  }

  function setUserUseReserveAsCollateral(
    address asset,
    bool useAsCollateral
  ) external {
    SupplyLogic.executeUseReserveAsCollateral(
      ps().usersConfig[msgSender()],
      asset,
      useAsCollateral,
      ps().usersEModeCategory[msgSender()]
    );
  }

  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external {
    SupplyLogic.executeSupply(
      DataTypes.ExecuteSupplyParams({
        asset: asset,
        amount: amount,
        onBehalfOf: onBehalfOf,
        referralCode: referralCode
      })
    );
  }
}
