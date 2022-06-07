// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { PoolLogic } from "@logic/PoolLogic.sol";

import { Errors } from "@helpers/Errors.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";

import { DataTypes } from "@types/DataTypes.sol";

contract AdminEntry is Modifiers {
  function mintToTreasury(address[] calldata assets) external {
    PoolLogic.executeMintToTreasury(assets);
  }

  function initReserve(
    address asset,
    address aTokenAddress,
    address stableDebtAddress,
    address variableDebtAddress,
    address interestRateStrategyAddress
  ) external onlyPoolAdmin {
    if (
      PoolLogic.executeInitReserve(
        DataTypes.InitReserveParams({
          asset: asset,
          aTokenAddress: aTokenAddress,
          stableDebtAddress: stableDebtAddress,
          variableDebtAddress: variableDebtAddress,
          interestRateStrategyAddress: interestRateStrategyAddress,
          reservesCount: ps().reservesCount,
          maxNumberReserves: ReserveConfiguration.MAX_RESERVES_COUNT
        })
      )
    ) {
      ps().reservesCount++;
    }
  }

  function dropReserve(address asset) external onlyPoolAdmin {
    PoolLogic.executeDropReserve(asset);
  }

  function setReserveInterestRateStrategyAddress(
    address asset,
    address rateStrategyAddress
  ) external onlyPoolAdmin {
    require(asset != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
    require(
      ps().reserves[asset].id != 0 || ps().reservesList[0] == asset,
      Errors.ASSET_NOT_LISTED
    );
    ps()
      .reserves[asset]
      .interestRateStrategyAddress = rateStrategyAddress;
  }

  function setConfiguration(
    address asset,
    DataTypes.ReserveConfigurationMap calldata configuration
  ) external onlyPoolAdmin {
    require(asset != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
    require(
      ps().reserves[asset].id != 0 || ps().reservesList[0] == asset,
      Errors.ASSET_NOT_LISTED
    );
    ps().reserves[asset].configuration = configuration;
  }

  function updateBridgeProtocolFee(uint256 protocolFee)
    external
    onlyPoolAdmin
  {
    ps().bridgeProtocolFee = protocolFee;
  }

  function updateFlashloanPremiums(
    uint128 flashLoanPremiumTotal,
    uint128 flashLoanPremiumToProtocol
  ) external onlyPoolAdmin {
    ps().flashLoanPremiumTotal = flashLoanPremiumTotal;
    ps().flashLoanPremiumToProtocol = flashLoanPremiumToProtocol;
  }

  function configureEModeCategory(
    uint8 id,
    DataTypes.EModeCategory memory category
  ) external onlyPoolAdmin {
    // category 0 is reserved for volatile heterogeneous assets and it's always disabled
    require(id != 0, Errors.EMODE_CATEGORY_RESERVED);
    ps().eModeCategories[id] = category;
  }

  function resetIsolationModeTotalDebt(address asset)
    external
    onlyPoolAdmin
  {
    PoolLogic.executeResetIsolationModeTotalDebt(asset);
  }

  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external onlyPoolAdmin {
    PoolLogic.executeRescueTokens(token, to, amount);
  }
}
