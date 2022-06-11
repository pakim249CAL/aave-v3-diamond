// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { PoolLogic } from "@logic/PoolLogic.sol";
import { OracleLogic } from "@logic/OracleLogic.sol";

import { Errors } from "@helpers/Errors.sol";

import { WadRayMath } from "@math/WadRayMath.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";

import { DataTypes } from "@types/DataTypes.sol";

contract AdminEntry is Modifiers {
  function mintToTreasury(address[] calldata assets) external {
    PoolLogic.executeMintToTreasury(assets);
  }

  function initReserve(address asset) external onlyPoolAdmin {
    if (
      PoolLogic.executeInitReserve(
        DataTypes.InitReserveParams({
          asset: asset,
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

  function setAssetSources(
    address[] calldata assets,
    address[] calldata sources
  ) external onlyPoolAdmin {
    OracleLogic.setAssetsSources(assets, sources);
  }

  function setFallbackOracle(address fallbackOracle)
    external
    onlyPoolAdmin
  {
    OracleLogic.setFallbackOracle(fallbackOracle);
  }

  function setSequencerOracle(address newSequencerOracle)
    external
    onlyPoolAdmin
  {
    OracleLogic.setSequencerOracle(newSequencerOracle);
  }

  function setGracePeriod(uint256 newGracePeriod)
    external
    onlyPoolAdmin
  {
    OracleLogic.setGracePeriod(newGracePeriod);
  }

  function setInterestRateStrategy(
    uint256 reserveId,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2,
    uint256 stableRateSlope1,
    uint256 stableRateSlope2,
    uint256 baseStableRateOffset,
    uint256 stableRateExcessOffset,
    uint256 optimalStableToTotalDebtRatio
  ) external onlyPoolAdmin {
    DataTypes.InterestRateStrategy storage strategy = irs()
      .interestRateStrategies[reserveId];
    require(
      WadRayMath.RAY >= optimalUsageRatio,
      Errors.INVALID_OPTIMAL_USAGE_RATIO
    );
    require(
      WadRayMath.RAY >= optimalStableToTotalDebtRatio,
      Errors.INVALID_OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO
    );
    strategy.OPTIMAL_USAGE_RATIO = optimalUsageRatio;
    strategy.MAX_EXCESS_USAGE_RATIO =
      WadRayMath.RAY -
      optimalUsageRatio;
    strategy
      .OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO = optimalStableToTotalDebtRatio;
    strategy.MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO =
      WadRayMath.RAY -
      optimalStableToTotalDebtRatio;
    strategy.baseVariableBorrowRate = baseVariableBorrowRate;
    strategy.variableRateSlope1 = variableRateSlope1;
    strategy.variableRateSlope2 = variableRateSlope2;
    strategy.stableRateSlope1 = stableRateSlope1;
    strategy.stableRateSlope2 = stableRateSlope2;
    strategy.baseStableRateOffset = baseStableRateOffset;
    strategy.stableRateExcessOffset = stableRateExcessOffset;
  }
}
