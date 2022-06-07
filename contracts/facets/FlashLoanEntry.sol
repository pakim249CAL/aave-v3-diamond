// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { FlashLoanLogic } from "@logic/FlashLoanLogic.sol";
import { AccessControlLogic } from "@logic/AccessControlLogic.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

contract FlashLoanEntry is Modifiers {
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata interestRateModes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external {
    DataTypes.FlashloanParams memory flashParams = DataTypes
      .FlashloanParams({
        receiverAddress: receiverAddress,
        assets: assets,
        amounts: amounts,
        interestRateModes: interestRateModes,
        onBehalfOf: onBehalfOf,
        params: params,
        referralCode: referralCode,
        flashLoanPremiumToProtocol: ps().flashLoanPremiumToProtocol,
        flashLoanPremiumTotal: ps().flashLoanPremiumTotal,
        maxStableRateBorrowSizePercent: ps()
          .maxStableRateBorrowSizePercent,
        reservesCount: ps().reservesCount,
        userEModeCategory: ps().usersEModeCategory[onBehalfOf],
        isAuthorizedFlashBorrower: AccessControlLogic.isFlashBorrower(
          msg.sender
        )
      });

    FlashLoanLogic.executeFlashLoan(flashParams);
  }

  function flashLoanSimple(
    address receiverAddress,
    address asset,
    uint256 amount,
    bytes calldata params,
    uint16 referralCode
  ) external {
    DataTypes.FlashloanSimpleParams memory flashParams = DataTypes
      .FlashloanSimpleParams({
        receiverAddress: receiverAddress,
        asset: asset,
        amount: amount,
        params: params,
        referralCode: referralCode,
        flashLoanPremiumToProtocol: ps().flashLoanPremiumToProtocol,
        flashLoanPremiumTotal: ps().flashLoanPremiumTotal
      });
    FlashLoanLogic.executeFlashLoanSimple(flashParams);
  }
}
