// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { PoolLogic } from "@logic/PoolLogic.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";

contract Lens is Modifiers {
  using ReserveLogic for DataTypes.ReserveData;

  function getReserveData(address asset)
    external
    view
    returns (DataTypes.ReserveData memory)
  {
    return ps().reserves[asset];
  }

  function getUserAccountData(address user)
    external
    view
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    )
  {
    return
      PoolLogic.executeGetUserAccountData(
        DataTypes.CalculateUserAccountDataParams({
          userConfig: ps().usersConfig[user],
          reservesCount: ps().reservesCount,
          user: user,
          oracle: address(0), //TODO: Add oracle
          userEModeCategory: ps().usersEModeCategory[user]
        })
      );
  }

  function getConfiguration(address asset)
    external
    view
    returns (DataTypes.ReserveConfigurationMap memory)
  {
    return ps().reserves[asset].configuration;
  }

  function getUserConfiguration(address user)
    external
    view
    returns (DataTypes.UserConfigurationMap memory)
  {
    return ps().usersConfig[user];
  }

  function getReserveNormalizedIncome(address asset)
    external
    view
    returns (uint256)
  {
    return ps().reserves[asset].getNormalizedIncome();
  }

  function getReserveNormalizedVariableDebt(address asset)
    external
    view
    returns (uint256)
  {
    return ps().reserves[asset].getNormalizedDebt();
  }

  function getReservesList()
    external
    view
    returns (address[] memory)
  {
    uint256 reservesListCount = ps().reservesCount;
    uint256 droppedReservesCount = 0;
    address[] memory reservesList = new address[](reservesListCount);

    for (uint256 i = 0; i < reservesListCount; i++) {
      if (ps().reservesList[i] != address(0)) {
        reservesList[i - droppedReservesCount] = ps().reservesList[i];
      } else {
        droppedReservesCount++;
      }
    }

    // Reduces the length of the reserves array by `droppedReservesCount`
    assembly {
      mstore(
        reservesList,
        sub(reservesListCount, droppedReservesCount)
      )
    }
    return reservesList;
  }

  function getReserveAddressById(uint16 id)
    external
    view
    returns (address)
  {
    return ps().reservesList[id];
  }

  function MAX_STABLE_RATE_BORROW_SIZE_PERCENT()
    external
    view
    returns (uint256)
  {
    return ps().maxStableRateBorrowSizePercent;
  }

  function BRIDGE_PROTOCOL_FEE() external view returns (uint256) {
    return ps().bridgeProtocolFee;
  }

  function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128) {
    return ps().flashLoanPremiumTotal;
  }

  function FLASHLOAN_PREMIUM_TO_PROTOCOL()
    external
    view
    returns (uint128)
  {
    return ps().flashLoanPremiumToProtocol;
  }

  function MAX_NUMBER_RESERVES() external pure returns (uint16) {
    return ReserveConfiguration.MAX_RESERVES_COUNT;
  }

  function getEModeCategoryData(uint8 id)
    external
    view
    returns (DataTypes.EModeCategory memory)
  {
    return ps().eModeCategories[id];
  }

  function getUserEMode(address user)
    external
    view
    returns (uint256)
  {
    return ps().usersEModeCategory[user];
  }
}
