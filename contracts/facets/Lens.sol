// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { PoolLogic } from "@logic/PoolLogic.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";
import { OracleLogic } from "@logic/OracleLogic.sol";
import { TokenLogic } from "@logic/TokenLogic.sol";

import { DataTypes } from "@types/DataTypes.sol";
import { IERC20Permit } from "@interfaces/IERC20Permit.sol";
import { IERC20Detailed } from "@interfaces/IERC20Detailed.sol";
import { IStableDebtToken } from "@interfaces/IStableDebtToken.sol";
import { IVariableDebtToken } from "@interfaces/IVariableDebtToken.sol";
import { WadRayMath } from "@math/WadRayMath.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";
import { UserConfiguration } from "@configuration/UserConfiguration.sol";

contract Lens is Modifiers {
  using ReserveLogic for DataTypes.ReserveData;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using WadRayMath for uint256;

  struct TokenData {
    string symbol;
    address tokenAddress;
  }

  address constant MKR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
  address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function getReserveData(address asset)
    public
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
          userEModeCategory: ps().usersEModeCategory[user]
        })
      );
  }

  function getConfiguration(address asset)
    public
    view
    returns (DataTypes.ReserveConfigurationMap memory)
  {
    return ps().reserves[asset].configuration;
  }

  function getUserConfiguration(address user)
    public
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

  function getReservesList() public view returns (address[] memory) {
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

  function getAssetPrice(address asset)
    external
    view
    returns (uint256)
  {
    return OracleLogic.getAssetPrice(asset);
  }

  function getAssetsPrices(address[] calldata assets)
    external
    view
    returns (uint256[] memory)
  {
    uint256[] memory prices = new uint256[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      prices[i] = OracleLogic.getAssetPrice(assets[i]);
    }
    return prices;
  }

  function getSourceOfAsset(address asset)
    external
    view
    returns (address)
  {
    return address(os().assetsSources[asset]);
  }

  function getFallbackOracle() external view returns (address) {
    return address(os().fallbackOracle);
  }

  function getPriceOracleSentinel() external view returns (address) {
    return address(os().sequencerOracle);
  }

  function getGracePeriod() external view returns (uint256) {
    return os().gracePeriod;
  }

  function isBorrowAllowed() external view returns (bool) {
    return OracleLogic.isUpAndGracePeriodPassed();
  }

  function isLiquidationAllowed() external view returns (bool) {
    return OracleLogic.isUpAndGracePeriodPassed();
  }

  /**
   * @notice Returns the list of the existing reserves in the pool.
   * @dev Handling MKR and ETH in a different way since they do not have standard `symbol` functions.
   * @return The list of reserves, pairs of symbols and addresses
   */
  function getAllReservesTokens()
    external
    view
    returns (TokenData[] memory)
  {
    address[] memory reserves = getReservesList();
    TokenData[] memory reservesTokens = new TokenData[](
      reserves.length
    );
    for (uint256 i = 0; i < reserves.length; i++) {
      if (reserves[i] == MKR) {
        reservesTokens[i] = TokenData({
          symbol: "MKR",
          tokenAddress: reserves[i]
        });
        continue;
      }
      if (reserves[i] == ETH) {
        reservesTokens[i] = TokenData({
          symbol: "ETH",
          tokenAddress: reserves[i]
        });
        continue;
      }
      reservesTokens[i] = TokenData({
        symbol: IERC20Detailed(reserves[i]).symbol(),
        tokenAddress: reserves[i]
      });
    }
    return reservesTokens;
  }

  /**
   * @notice Returns the configuration data of the reserve
   * @dev Not returning borrow and supply caps for compatibility, nor pause flag
   * @param asset The address of the underlying asset of the reserve
   * @return decimals The number of decimals of the reserve
   * @return ltv The ltv of the reserve
   * @return liquidationThreshold The liquidationThreshold of the reserve
   * @return liquidationBonus The liquidationBonus of the reserve
   * @return reserveFactor The reserveFactor of the reserve
   * @return usageAsCollateralEnabled True if the usage as collateral is enabled, false otherwise
   * @return borrowingEnabled True if borrowing is enabled, false otherwise
   * @return stableBorrowRateEnabled True if stable rate borrowing is enabled, false otherwise
   * @return isActive True if it is active, false otherwise
   * @return isFrozen True if it is frozen, false otherwise
   **/
  function getReserveConfigurationData(address asset)
    external
    view
    returns (
      uint256 decimals,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 reserveFactor,
      bool usageAsCollateralEnabled,
      bool borrowingEnabled,
      bool stableBorrowRateEnabled,
      bool isActive,
      bool isFrozen
    )
  {
    DataTypes.ReserveConfigurationMap
      memory configuration = getConfiguration(asset);

    (
      ltv,
      liquidationThreshold,
      liquidationBonus,
      decimals,
      reserveFactor,

    ) = configuration.getParams();

    (
      isActive,
      isFrozen,
      borrowingEnabled,
      stableBorrowRateEnabled,

    ) = configuration.getFlags();

    usageAsCollateralEnabled = liquidationThreshold != 0;
  }

  /**
   * Returns the efficiency mode category of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The eMode id of the reserve
   */
  function getReserveEModeCategory(address asset)
    external
    view
    returns (uint256)
  {
    DataTypes.ReserveConfigurationMap
      memory configuration = getConfiguration(asset);
    return configuration.getEModeCategory();
  }

  /**
   * @notice Returns the caps parameters of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return borrowCap The borrow cap of the reserve
   * @return supplyCap The supply cap of the reserve
   **/
  function getReserveCaps(address asset)
    external
    view
    returns (uint256 borrowCap, uint256 supplyCap)
  {
    (borrowCap, supplyCap) = getConfiguration(asset).getCaps();
  }

  /**
   * @notice Returns if the pool is paused
   * @param asset The address of the underlying asset of the reserve
   * @return isPaused True if the pool is paused, false otherwise
   **/
  function getPaused(address asset)
    external
    view
    returns (bool isPaused)
  {
    (, , , , isPaused) = getConfiguration(asset).getFlags();
  }

  /**
   * @notice Returns the siloed borrowing flag
   * @param asset The address of the underlying asset of the reserve
   * @return True if the asset is siloed for borrowing
   **/
  function getSiloedBorrowing(address asset)
    external
    view
    returns (bool)
  {
    return getConfiguration(asset).getSiloedBorrowing();
  }

  /**
   * @notice Returns the protocol fee on the liquidation bonus
   * @param asset The address of the underlying asset of the reserve
   * @return The protocol fee on liquidation
   **/
  function getLiquidationProtocolFee(address asset)
    external
    view
    returns (uint256)
  {
    return getConfiguration(asset).getLiquidationProtocolFee();
  }

  /**
   * @notice Returns the unbacked mint cap of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The unbacked mint cap of the reserve
   **/
  function getUnbackedMintCap(address asset)
    external
    view
    returns (uint256)
  {
    return getConfiguration(asset).getUnbackedMintCap();
  }

  /**
   * @notice Returns the debt ceiling of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The debt ceiling of the reserve
   **/
  function getDebtCeiling(address asset)
    external
    view
    returns (uint256)
  {
    return getConfiguration(asset).getDebtCeiling();
  }

  /**
   * @notice Returns the debt ceiling decimals
   * @return The debt ceiling decimals
   **/
  function getDebtCeilingDecimals() external pure returns (uint256) {
    return ReserveConfiguration.DEBT_CEILING_DECIMALS;
  }

  /**
   * @notice Returns the reserve data
   * @param asset The address of the underlying asset of the reserve
   * @return unbacked The amount of unbacked tokens
   * @return accruedToTreasuryScaled The scaled amount of tokens accrued to treasury that is to be minted
   * @return totalAToken The total supply of the aToken
   * @return totalStableDebt The total stable debt of the reserve
   * @return totalVariableDebt The total variable debt of the reserve
   * @return liquidityRate The liquidity rate of the reserve
   * @return variableBorrowRate The variable borrow rate of the reserve
   * @return stableBorrowRate The stable borrow rate of the reserve
   * @return averageStableBorrowRate The average stable borrow rate of the reserve
   * @return liquidityIndex The liquidity index of the reserve
   * @return variableBorrowIndex The variable borrow index of the reserve
   * @return lastUpdateTimestamp The timestamp of the last update of the reserve
   **/
  function getReserveDataFull(address asset)
    external
    view
    returns (
      uint256 unbacked,
      uint256 accruedToTreasuryScaled,
      uint256 totalAToken,
      uint256 totalStableDebt,
      uint256 totalVariableDebt,
      uint256 liquidityRate,
      uint256 variableBorrowRate,
      uint256 stableBorrowRate,
      uint256 averageStableBorrowRate,
      uint256 liquidityIndex,
      uint256 variableBorrowIndex,
      uint40 lastUpdateTimestamp
    )
  {
    DataTypes.ReserveData memory reserve = getReserveData(asset);

    return (
      reserve.unbacked,
      reserve.accruedToTreasury,
      TokenLogic.totalSupplyAToken(reserve.id),
      TokenLogic.totalSupplyStableDebt(reserve.id),
      TokenLogic.totalSupplyVariableDebt(reserve.id),
      reserve.currentLiquidityRate,
      reserve.currentVariableBorrowRate,
      reserve.currentStableBorrowRate,
      ts().avgStableRate[reserve.id],
      reserve.liquidityIndex,
      reserve.variableBorrowIndex,
      reserve.lastUpdateTimestamp
    );
  }

  /**
   * @notice Returns the total supply of aTokens for a given asset
   * @param asset The address of the underlying asset of the reserve
   * @return The total supply of the aToken
   **/
  function getATokenTotalSupply(address asset)
    external
    view
    returns (uint256)
  {
    DataTypes.ReserveData memory reserve = getReserveData(asset);
    return TokenLogic.totalSupplyAToken(reserve.id);
  }

  /**
   * @notice Returns the total debt for a given asset
   * @param asset The address of the underlying asset of the reserve
   * @return The total debt for asset
   **/
  function getTotalDebt(address asset)
    external
    view
    returns (uint256)
  {
    DataTypes.ReserveData memory reserve = getReserveData(asset);
    return
      TokenLogic.totalSupplyStableDebt(reserve.id) +
      TokenLogic.totalSupplyVariableDebt(reserve.id);
  }

  /**
   * @notice Returns the user data in a reserve
   * @param asset The address of the underlying asset of the reserve
   * @param user The address of the user
   * @return currentATokenBalance The current AToken balance of the user
   * @return currentStableDebt The current stable debt of the user
   * @return currentVariableDebt The current variable debt of the user
   * @return principalStableDebt The principal stable debt of the user
   * @return scaledVariableDebt The scaled variable debt of the user
   * @return stableBorrowRate The stable borrow rate of the user
   * @return liquidityRate The liquidity rate of the reserve
   * @return stableRateLastUpdated The timestamp of the last update of the user stable rate
   * @return usageAsCollateralEnabled True if the user is using the asset as collateral, false
   *         otherwise
   **/
  function getUserReserveData(address asset, address user)
    external
    view
    returns (
      uint256 currentATokenBalance,
      uint256 currentStableDebt,
      uint256 currentVariableDebt,
      uint256 principalStableDebt,
      uint256 scaledVariableDebt,
      uint256 stableBorrowRate,
      uint256 liquidityRate,
      uint40 stableRateLastUpdated,
      bool usageAsCollateralEnabled
    )
  {
    DataTypes.ReserveData memory reserve = getReserveData(asset);

    DataTypes.UserConfigurationMap
      memory userConfig = getUserConfiguration(user);

    currentATokenBalance = TokenLogic.balanceOfAToken(
      reserve.id,
      user
    );
    currentVariableDebt = TokenLogic.balanceOfVariableDebt(
      reserve.id,
      user
    );
    currentStableDebt = TokenLogic.balanceOfStableDebt(
      reserve.id,
      user
    );

    principalStableDebt = ts()
    .stableDebtBalances[reserve.id][user].balance;
    scaledVariableDebt = ts()
    .variableDebtBalances[reserve.id][user].balance;
    liquidityRate = reserve.currentLiquidityRate;
    stableBorrowRate = ts()
    .stableDebtBalances[reserve.id][user].prevIndex;
    stableRateLastUpdated = ts().stableDebtTimestamps[reserve.id][
      user
    ];
    usageAsCollateralEnabled = userConfig.isUsingAsCollateral(
      reserve.id
    );
  }
}
