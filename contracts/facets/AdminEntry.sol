// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { PoolLogic } from "@logic/PoolLogic.sol";
import { OracleLogic } from "@logic/OracleLogic.sol";
import { InterestRateLogic } from "@logic/InterestRateLogic.sol";

import { Errors } from "@helpers/Errors.sol";

import { WadRayMath } from "@math/WadRayMath.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";

import { DataTypes } from "@types/DataTypes.sol";

contract AdminEntry is Modifiers {
  function initMarket() external onlyOwner {
    // Set up EIP712
    // Set up fallback oracle and sequencer (sentinel) oracle and grace period
    // Set up roles
    // Set up bridge protocol fee, flashloan fee, flashloan protocol fee
    // Set up max stable debt
    // Set up treasury
  }

  function mintToTreasury(address[] calldata assets) external {
    PoolLogic.executeMintToTreasury(assets);
  }

  function dropReserve(address asset) external onlyOwner {
    PoolLogic.executeDropReserve(asset);
  }

  function setConfiguration(
    address asset,
    DataTypes.ReserveConfigurationMap calldata configuration
  ) external onlyOwner {
    require(asset != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
    require(
      ps().reserves[asset].id != 0 || ps().reservesList[0] == asset,
      Errors.ASSET_NOT_LISTED
    );
    ps().reserves[asset].configuration = configuration;
  }

  function configureEModeCategory(
    uint8 id,
    DataTypes.EModeCategory memory category
  ) external onlyOwner {
    // category 0 is reserved for volatile heterogeneous assets and it's always disabled
    require(id != 0, Errors.EMODE_CATEGORY_RESERVED);
    ps().eModeCategories[id] = category;
  }

  function resetIsolationModeTotalDebt(address asset)
    external
    onlyOwner
  {
    PoolLogic.executeResetIsolationModeTotalDebt(asset);
  }

  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    PoolLogic.executeRescueTokens(token, to, amount);
  }
}
