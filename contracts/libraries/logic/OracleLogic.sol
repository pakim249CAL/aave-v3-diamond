// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { AggregatorInterface } from "@interfaces/AggregatorInterface.sol";
import { Errors } from "@helpers/Errors.sol";
import { IPriceOracleGetter } from "@interfaces/IPriceOracleGetter.sol";
import { ISequencerOracle } from "@interfaces/ISequencerOracle.sol";

library OracleLogic {
  address constant BASE_CURRENCY =
    0x0000000000000000000000000000000000000348;
  uint256 constant BASE_CURRENCY_UNIT = 1e18;

  /**
   * @dev Emitted after the base currency is set
   * @param baseCurrency The base currency of used for price quotes
   * @param baseCurrencyUnit The unit of the base currency
   */
  event BaseCurrencySet(
    address indexed baseCurrency,
    uint256 baseCurrencyUnit
  );

  /**
   * @dev Emitted after the price source of an asset is updated
   * @param asset The address of the asset
   * @param source The price source of the asset
   */
  event AssetSourceUpdated(
    address indexed asset,
    address indexed source
  );

  /**
   * @dev Emitted after the address of fallback oracle is updated
   * @param fallbackOracle The address of the fallback oracle
   */
  event FallbackOracleUpdated(address indexed fallbackOracle);

  /**
   * @dev Emitted after the sequencer oracle is updated
   * @param newSequencerOracle The new sequencer oracle
   */
  event SequencerOracleUpdated(address newSequencerOracle);

  /**
   * @dev Emitted after the grace period is updated
   * @param newGracePeriod The new grace period value
   */
  event GracePeriodUpdated(uint256 newGracePeriod);

  function ps()
    internal
    pure
    returns (LibStorage.PoolStorage storage)
  {
    return LibStorage.poolStorage();
  }

  function os()
    internal
    pure
    returns (LibStorage.OracleStorage storage)
  {
    return LibStorage.oracleStorage();
  }

  function setAssetsSources(
    address[] memory assets,
    address[] memory sources
  ) internal {
    require(
      assets.length == sources.length,
      Errors.INCONSISTENT_PARAMS_LENGTH
    );
    for (uint256 i = 0; i < assets.length; i++) {
      os().assetsSources[assets[i]] = AggregatorInterface(sources[i]);
      emit AssetSourceUpdated(assets[i], sources[i]);
    }
  }

  function setFallbackOracle(address fallbackOracle) internal {
    os().fallbackOracle = IPriceOracleGetter(fallbackOracle);
    emit FallbackOracleUpdated(fallbackOracle);
  }

  function getAssetPrice(address asset)
    internal
    view
    returns (uint256)
  {
    AggregatorInterface source = os().assetsSources[asset];

    if (asset == BASE_CURRENCY) {
      return BASE_CURRENCY_UNIT;
    } else if (address(source) == address(0)) {
      return os().fallbackOracle.getAssetPrice(asset);
    } else {
      int256 price = source.latestAnswer();
      if (price > 0) {
        return uint256(price);
      } else {
        return os().fallbackOracle.getAssetPrice(asset);
      }
    }
  }

  function isBorrowAllowed() internal view returns (bool) {
    return isUpAndGracePeriodPassed();
  }

  function isLiquidationAllowed() internal view returns (bool) {
    return isUpAndGracePeriodPassed();
  }

  /**
   * @notice Checks the sequencer oracle is healthy: is up and grace period passed.
   * @return True if the SequencerOracle is up and the grace period passed, false otherwise
   */
  function isUpAndGracePeriodPassed() internal view returns (bool) {
    (, int256 answer, , uint256 lastUpdateTimestamp, ) = os()
      .sequencerOracle
      .latestRoundData();
    return
      answer == 0 &&
      block.timestamp - lastUpdateTimestamp > os().gracePeriod;
  }

  function setSequencerOracle(address newSequencerOracle) internal {
    os().sequencerOracle = ISequencerOracle(newSequencerOracle);
    emit SequencerOracleUpdated(newSequencerOracle);
  }

  function setGracePeriod(uint256 newGracePeriod) internal {
    os().gracePeriod = newGracePeriod;
    emit GracePeriodUpdated(newGracePeriod);
  }
}
