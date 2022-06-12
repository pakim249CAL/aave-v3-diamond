// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibDiamond } from "@diamond/libraries/LibDiamond.sol";
import { LibStorage } from "@storage/LibStorage.sol";
import { Modifiers } from "@abstract/Modifiers.sol";

import { FunctionSelectorEntry } from "@diamond/facets/FunctionSelectorEntry.sol";
import { FunctionLens } from "@diamond/facets/FunctionLens.sol";
import { OwnershipEntry } from "@diamond/facets/OwnershipEntry.sol";
import { BorrowEntry } from "@facets/BorrowEntry.sol";
import { SupplyEntry } from "@facets/SupplyEntry.sol";
import { LiquidationEntry } from "@facets/LiquidationEntry.sol";
import { Lens } from "@facets/Lens.sol";

import { PoolLogic } from "@logic/PoolLogic.sol";
import { OracleLogic } from "@logic/OracleLogic.sol";
import { InterestRateLogic } from "@logic/InterestRateLogic.sol";
import { EIP712Logic } from "@logic/EIP712Logic.sol";

import { IPriceOracleGetter } from "@interfaces/IPriceOracleGetter.sol";
import { ISequencerOracle } from "@interfaces/ISequencerOracle.sol";
import { AggregatorInterface } from "@interfaces/AggregatorInterface.sol";

import { Errors } from "@helpers/Errors.sol";

import { WadRayMath } from "@math/WadRayMath.sol";

import { DataTypes } from "@types/DataTypes.sol";

import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";

import { DataTypes } from "@types/DataTypes.sol";

contract InitMarket is Modifiers {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  struct DeployedAddresses {
    address functionLens;
    address ownershipEntry;
    address borrowEntry;
    address supplyEntry;
    address liquidationEntry;
    address lens;
  }

  function initAll(DeployedAddresses memory deployedAddresses)
    external
  {
    addFunctionsToDiamond(deployedAddresses);
    initPool();
    initMarket(
      0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7,
      InitInterestRateStrategyParams({
        optimalUsageRatio: 450000000000000000000000000,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 70000000000000000000000000,
        variableRateSlope2: 3000000000000000000000000000,
        stableRateSlope1: 0,
        stableRateSlope2: 0,
        baseStableRateOffset: 20000000000000000000000000,
        stableRateExcessOffset: 50000000000000000000000000,
        optimalStableToTotalDebtRatio: 200000000000000000000000000
      }),
      ConfigureReserveParams({
        decimals: 18,
        ltv: 2500,
        lt: 4500,
        lb: 11500,
        rf: 2000,
        borrowEnabled: true
      }),
      0xDD229Ce42f11D8Ee7fFf29bDB71C7b81352e11be
    );
    initMarket(
      0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
      InitInterestRateStrategyParams({
        optimalUsageRatio: 450000000000000000000000000,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 70000000000000000000000000,
        variableRateSlope2: 3000000000000000000000000000,
        stableRateSlope1: 0,
        stableRateSlope2: 0,
        baseStableRateOffset: 20000000000000000000000000,
        stableRateExcessOffset: 50000000000000000000000000,
        optimalStableToTotalDebtRatio: 200000000000000000000000000
      }),
      ConfigureReserveParams({
        decimals: 6,
        ltv: 7500,
        lt: 8500,
        lb: 10400,
        rf: 1000,
        borrowEnabled: true
      }),
      0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7
    );
  }

  function addFunctionsToDiamond(DeployedAddresses memory addresses)
    public
  {
    LibDiamond.addFunctions(
      addresses.functionLens,
      functionLensSelectors()
    );
    LibDiamond.addFunctions(
      addresses.ownershipEntry,
      ownershipEntrySelectors()
    );
    LibDiamond.addFunctions(
      addresses.borrowEntry,
      borrowEntrySelectors()
    );
    LibDiamond.addFunctions(
      addresses.supplyEntry,
      supplyEntrySelectors()
    );
    LibDiamond.addFunctions(
      addresses.liquidationEntry,
      liquidationEntrySelectors()
    );
    LibDiamond.addFunctions(addresses.lens, lensSelectors());
  }

  function initPool() public {
    initEIP712("AAVE V3 Diamond", "1");
    // No fallback or sentinel oracles for now
    initPoolOracles(address(0), address(0), 0);
    initPoolParams(
      0,
      0,
      0,
      0,
      0x5fb4f321C4366C93EEC1A70447c87d74C3602b0f
    );
  }

  struct InitInterestRateStrategyParams {
    uint256 optimalUsageRatio;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
    uint256 stableRateSlope1;
    uint256 stableRateSlope2;
    uint256 baseStableRateOffset;
    uint256 stableRateExcessOffset;
    uint256 optimalStableToTotalDebtRatio;
  }

  struct ConfigureReserveParams {
    uint256 decimals;
    uint256 ltv;
    uint256 lt;
    uint256 lb;
    uint256 rf;
    bool borrowEnabled;
  }

  function initMarket(
    address _asset,
    InitInterestRateStrategyParams memory irsParams,
    ConfigureReserveParams memory reserveParams,
    address _oracle
  ) public {
    initReserve(_asset);
    uint256 reserveId = ps().reserves[_asset].id;
    configureReserve(_asset, reserveParams);
    initInterestRateStrategy(reserveId, irsParams);
    initMarketOracle(_asset, _oracle);
  }

  function initEIP712(string memory name, string memory version)
    public
  {
    LibStorage.EIP712Storage storage s = LibStorage.eip712Storage();
    bytes32 hashedName = keccak256(bytes(name));
    bytes32 hashedVersion = keccak256(bytes(version));
    bytes32 typeHash = keccak256(
      "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    s.HASHED_NAME = hashedName;
    s.HASHED_VERSION = hashedVersion;
    s.CACHED_CHAIN_ID = block.chainid;
    s.CACHED_DOMAIN_SEPARATOR = EIP712Logic._buildDomainSeparator(
      typeHash,
      hashedName,
      hashedVersion
    );
    s.TYPE_HASH = typeHash;
  }

  function initPoolOracles(
    address _fallbackOracle,
    address _sequencerOracle,
    uint256 _gracePeriod
  ) public {
    LibStorage.OracleStorage storage s = LibStorage.oracleStorage();
    s.fallbackOracle = IPriceOracleGetter(_fallbackOracle);
    s.sequencerOracle = ISequencerOracle(_sequencerOracle);
    s.gracePeriod = _gracePeriod;
  }

  function initPoolParams(
    uint256 _bridgeProtocolFee,
    uint128 _flashLoanPremiumTotal,
    uint128 _flashLoanPremiumToProtocol,
    uint64 _maxStableRateBorrowSizePercent,
    address _treasury
  ) public {
    LibStorage.PoolStorage storage s = LibStorage.poolStorage();
    require(
      _bridgeProtocolFee < 10000,
      "InitMarket: Bridge fee too high"
    );
    require(
      _flashLoanPremiumTotal < 10000,
      "InitMarket: Flash loan fee too high"
    );
    require(
      _flashLoanPremiumToProtocol <= _flashLoanPremiumTotal,
      "InitMarket: Flash loan protocol fee too high"
    );
    require(
      _maxStableRateBorrowSizePercent < 10000,
      "InitMarket: Stable rate borrow size percent too high"
    );
    s.bridgeProtocolFee = _bridgeProtocolFee;
    s.flashLoanPremiumTotal = _flashLoanPremiumTotal;
    s.flashLoanPremiumToProtocol = _flashLoanPremiumToProtocol;
    s
      .maxStableRateBorrowSizePercent = _maxStableRateBorrowSizePercent;
    s.treasury = _treasury;
  }

  function initMarketOracle(address _asset, address _oracle) public {
    os().assetsSources[_asset] = AggregatorInterface(_oracle);
  }

  function initReserve(address _asset) public {
    PoolLogic.executeInitReserve(_asset);
  }

  function initInterestRateStrategy(
    uint256 _reserveId,
    InitInterestRateStrategyParams memory params
  ) public {
    LibStorage.InterestRateStorage storage s = LibStorage
      .interestRateStorage();
    DataTypes.InterestRateStrategy storage strategy = s
      .interestRateStrategies[_reserveId];
    require(
      WadRayMath.RAY >= params.optimalUsageRatio,
      Errors.INVALID_OPTIMAL_USAGE_RATIO
    );
    require(
      WadRayMath.RAY >= params.optimalStableToTotalDebtRatio,
      Errors.INVALID_OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO
    );
    strategy.OPTIMAL_USAGE_RATIO = params.optimalUsageRatio;
    strategy.MAX_EXCESS_USAGE_RATIO =
      WadRayMath.RAY -
      params.optimalUsageRatio;
    strategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO = params
      .optimalStableToTotalDebtRatio;
    strategy.MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO =
      WadRayMath.RAY -
      params.optimalStableToTotalDebtRatio;
    strategy.baseVariableBorrowRate = params.baseVariableBorrowRate;
    strategy.variableRateSlope1 = params.variableRateSlope1;
    strategy.variableRateSlope2 = params.variableRateSlope2;
    strategy.stableRateSlope1 = params.stableRateSlope1;
    strategy.stableRateSlope2 = params.stableRateSlope2;
    strategy.baseStableRateOffset = params.baseStableRateOffset;
    strategy.stableRateExcessOffset = params.stableRateExcessOffset;
  }

  function configureReserve(
    address _asset,
    ConfigureReserveParams memory params
  ) public {
    DataTypes.ReserveConfigurationMap memory reserveConfig = DataTypes
      .ReserveConfigurationMap(0);

    reserveConfig.setDecimals(params.decimals);
    reserveConfig.setLtv(params.ltv);
    reserveConfig.setLiquidationThreshold(params.lt);
    reserveConfig.setLiquidationBonus(params.lb);
    reserveConfig.setReserveFactor(params.rf);
    reserveConfig.setBorrowingEnabled(params.borrowEnabled);

    reserveConfig.setActive(true);
    reserveConfig.setPaused(false);
    reserveConfig.setFrozen(false);
    ps().reserves[_asset].configuration = reserveConfig;
  }

  function functionLensSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory functionSelectors = new bytes4[](4);
    uint256 i;
    {
      functionSelectors[i++] = FunctionLens.facets.selector;
      functionSelectors[i++] = FunctionLens
        .facetFunctionSelectors
        .selector;
      functionSelectors[i++] = FunctionLens.facetAddresses.selector;
      functionSelectors[i++] = FunctionLens.facetAddress.selector;
    }
    return functionSelectors;
  }

  function ownershipEntrySelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory functionSelectors = new bytes4[](2);
    uint256 i;
    {
      functionSelectors[i++] = OwnershipEntry.owner.selector;
      functionSelectors[i++] = OwnershipEntry
        .transferOwnership
        .selector;
    }
    return functionSelectors;
  }

  function borrowEntrySelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory functionSelectors = new bytes4[](6);
    uint256 i;
    {
      functionSelectors[i++] = BorrowEntry.borrow.selector;
      functionSelectors[i++] = BorrowEntry.repay.selector;
      functionSelectors[i++] = BorrowEntry.repayWithPermit.selector;
      functionSelectors[i++] = BorrowEntry.repayWithATokens.selector;
      functionSelectors[i++] = BorrowEntry
        .swapBorrowRateMode
        .selector;
      functionSelectors[i++] = BorrowEntry
        .rebalanceStableBorrowRate
        .selector;
    }
    return functionSelectors;
  }

  function supplyEntrySelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory functionSelectors = new bytes4[](5);
    uint256 i;
    {
      functionSelectors[i++] = SupplyEntry.supply.selector;
      functionSelectors[i++] = SupplyEntry.supplyWithPermit.selector;
      functionSelectors[i++] = SupplyEntry.withdraw.selector;
      functionSelectors[i++] = SupplyEntry
        .setUserUseReserveAsCollateral
        .selector;
      functionSelectors[i++] = SupplyEntry.deposit.selector;
    }
    return functionSelectors;
  }

  function liquidationEntrySelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory functionSelectors = new bytes4[](1);
    uint256 i;
    {
      functionSelectors[i++] = LiquidationEntry
        .liquidationCall
        .selector;
    }
    return functionSelectors;
  }

  function lensSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory functionSelectors = new bytes4[](27);
    uint256 i;
    {
      functionSelectors[i++] = Lens.getReserveData.selector;
      functionSelectors[i++] = Lens.getUserAccountData.selector;
      functionSelectors[i++] = Lens.getConfiguration.selector;
      functionSelectors[i++] = Lens.getUserConfiguration.selector;
      functionSelectors[i++] = Lens
        .getReserveNormalizedIncome
        .selector;
      functionSelectors[i++] = Lens
        .getReserveNormalizedVariableDebt
        .selector;
      functionSelectors[i++] = Lens.getReservesList.selector;
      functionSelectors[i++] = Lens.getReserveAddressById.selector;
      functionSelectors[i++] = Lens
        .MAX_STABLE_RATE_BORROW_SIZE_PERCENT
        .selector;
      functionSelectors[i++] = Lens.BRIDGE_PROTOCOL_FEE.selector;
      functionSelectors[i++] = Lens.FLASHLOAN_PREMIUM_TOTAL.selector;
      functionSelectors[i++] = Lens
        .FLASHLOAN_PREMIUM_TO_PROTOCOL
        .selector;
      functionSelectors[i++] = Lens.MAX_NUMBER_RESERVES.selector;
      functionSelectors[i++] = Lens.getEModeCategoryData.selector;
      functionSelectors[i++] = Lens.getUserEMode.selector;
      functionSelectors[i++] = Lens.getAssetPrice.selector;
      functionSelectors[i++] = Lens.getAssetsPrices.selector;
      functionSelectors[i++] = Lens.getSourceOfAsset.selector;
      functionSelectors[i++] = Lens.getFallbackOracle.selector;
      functionSelectors[i++] = Lens.getPriceOracleSentinel.selector;
      functionSelectors[i++] = Lens.getGracePeriod.selector;
      functionSelectors[i++] = Lens.isBorrowAllowed.selector;
      functionSelectors[i++] = Lens.isLiquidationAllowed.selector;
      functionSelectors[i++] = Lens.getAllReservesTokens.selector;
      functionSelectors[i++] = Lens
        .getReserveConfigurationData
        .selector;
      functionSelectors[i++] = Lens.getReserveEModeCategory.selector;
      functionSelectors[i++] = Lens.getReserveCaps.selector;
      functionSelectors[i++] = Lens.getPaused.selector;
      functionSelectors[i++] = Lens.getSiloedBorrowing.selector;
      functionSelectors[i++] = Lens
        .getLiquidationProtocolFee
        .selector;
      functionSelectors[i++] = Lens.getUnbackedMintCap.selector;
      functionSelectors[i++] = Lens.getDebtCeiling.selector;
      functionSelectors[i++] = Lens.getDebtCeilingDecimals.selector;
      functionSelectors[i++] = Lens.getReserveDataFull.selector;
      functionSelectors[i++] = Lens.getATokenTotalSupply.selector;
      functionSelectors[i++] = Lens.getTotalDebt.selector;
      functionSelectors[i++] = Lens.getUserReserveData.selector;
    }
    return functionSelectors;
  }
}
