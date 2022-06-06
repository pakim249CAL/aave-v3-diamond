// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";
import { BridgeLogic } from "@logic/BridgeLogic.sol";
import { SupplyLogic } from "@logic/SupplyLogic.sol";
import { BorrowLogic } from "@logic/BorrowLogic.sol";
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
          oracle: address(this) // TODO
        })
      );
  }

  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external {
    BorrowLogic.executeBorrow(
      DataTypes.ExecuteBorrowParams({
        asset: asset,
        user: msg.sender,
        onBehalfOf: onBehalfOf,
        amount: amount,
        interestRateMode: DataTypes.InterestRateMode(
          interestRateMode
        ),
        referralCode: referralCode,
        releaseUnderlying: true,
        maxStableRateBorrowSizePercent: ps()
          .maxStableRateBorrowSizePercent,
        reservesCount: ps().reservesCount,
        oracle: address(0), //TODO
        userEModeCategory: ps().usersEModeCategory[onBehalfOf],
        priceOracleSentinel: address(0) //TODO
      })
    );
  }
}
