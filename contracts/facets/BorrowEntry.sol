// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { BorrowLogic } from "@logic/BorrowLogic.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

contract BorrowEntry is Modifiers {
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
        user: msgSender(),
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
        userEModeCategory: ps().usersEModeCategory[onBehalfOf]
      })
    );
  }

  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external returns (uint256) {
    return
      BorrowLogic.executeRepay(
        DataTypes.ExecuteRepayParams({
          asset: asset,
          amount: amount,
          interestRateMode: DataTypes.InterestRateMode(
            interestRateMode
          ),
          onBehalfOf: onBehalfOf,
          useATokens: false
        })
      );
  }

  function repayWithPermit(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external returns (uint256) {
    {
      IERC20Permit(asset).permit(
        msgSender(),
        address(this),
        amount,
        deadline,
        permitV,
        permitR,
        permitS
      );
    }
    {
      DataTypes.ExecuteRepayParams memory params = DataTypes
        .ExecuteRepayParams({
          asset: asset,
          amount: amount,
          interestRateMode: DataTypes.InterestRateMode(
            interestRateMode
          ),
          onBehalfOf: onBehalfOf,
          useATokens: false
        });
      return BorrowLogic.executeRepay(params);
    }
  }

  function repayWithATokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
  ) external returns (uint256) {
    return
      BorrowLogic.executeRepay(
        DataTypes.ExecuteRepayParams({
          asset: asset,
          amount: amount,
          interestRateMode: DataTypes.InterestRateMode(
            interestRateMode
          ),
          onBehalfOf: msgSender(),
          useATokens: true
        })
      );
  }

  function swapBorrowRateMode(address asset, uint256 interestRateMode)
    external
  {
    BorrowLogic.executeSwapBorrowRateMode(
      ps().usersConfig[msgSender()],
      asset,
      DataTypes.InterestRateMode(interestRateMode)
    );
  }

  function rebalanceStableBorrowRate(address asset, address user)
    external
  {
    BorrowLogic.executeRebalanceStableBorrowRate(asset, user);
  }
}
