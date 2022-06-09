pragma solidity 0.8.14;

import { UserConfiguration } from "@configuration/UserConfiguration.sol";
import { ReserveConfiguration } from "@configuration/ReserveConfiguration.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { IPriceOracleGetter } from "@interfaces/IPriceOracleGetter.sol";
import { AggregatorInterface } from "@interfaces/AggregatorInterface.sol";
import { ISequencerOracle } from "@interfaces/ISequencerOracle.sol";

library LibStorage {
  // Internal Structs

  struct RoleStorage {
    mapping(bytes32 => DataTypes.RoleData) roles;
  }

  struct PoolStorage {
    // Map of reserves and their data (underlyingAssetOfReserve => reserveData)
    mapping(address => DataTypes.ReserveData) reserves;
    // Map of users address and their configuration data (userAddress => userConfiguration)
    mapping(address => DataTypes.UserConfigurationMap) usersConfig;
    // List of reserves as a map (reserveId => reserve).
    // It is structured as a mapping for gas savings reasons, using the reserve id as index
    mapping(uint256 => address) reservesList;
    // List of eMode categories as a map (eModeCategoryId => eModeCategory).
    // It is structured as a mapping for gas savings reasons, using the eModeCategoryId as index
    mapping(uint8 => DataTypes.EModeCategory) eModeCategories;
    // Map of users address and their eMode category (userAddress => eModeCategoryId)
    mapping(address => uint8) usersEModeCategory;
    // Fee of the protocol bridge, expressed in bps
    uint256 bridgeProtocolFee;
    // Total FlashLoan Premium, expressed in bps
    uint128 flashLoanPremiumTotal;
    // FlashLoan premium paid to protocol treasury, expressed in bps
    uint128 flashLoanPremiumToProtocol;
    // Available liquidity that can be borrowed at once at stable rate, expressed in bps
    uint64 maxStableRateBorrowSizePercent;
    // Maximum number of active reserves there have been in the protocol. It is the upper bound of the reserves list
    uint16 reservesCount;
  }

  struct OracleStorage {
    // Map of asset price sources (asset => priceSource)
    mapping(address => AggregatorInterface) assetsSources;
    IPriceOracleGetter fallbackOracle;
    ISequencerOracle sequencerOracle;
    uint256 gracePeriod;
  }

  struct ERC1155Storage {
    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) balances;
    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) operatorApprovals;
  }

  struct EIP712Storage {
    bytes32 CACHED_DOMAIN_SEPARATOR;
    uint256 CACHED_CHAIN_ID;
    bytes32 HASHED_NAME;
    bytes32 HASHED_VERSION;
    bytes32 TYPE_HASH;
  }

  struct MetaStorage {
    mapping(address => uint256) nonces;
  }

  function poolStorage()
    internal
    pure
    returns (PoolStorage storage ps)
  {
    bytes32 position = keccak256("diamond.aave.v3.pool.storage");
    assembly {
      ps.slot := position
    }
  }

  function roleStorage()
    internal
    pure
    returns (RoleStorage storage rs)
  {
    bytes32 position = keccak256("diamond.aave.v3.role.storage");
    assembly {
      rs.slot := position
    }
  }

  function oracleStorage()
    internal
    pure
    returns (OracleStorage storage os)
  {
    bytes32 position = keccak256("diamond.aave.v3.oracle.storage");
    assembly {
      os.slot := position
    }
  }

  function erc1155Storage()
    internal
    pure
    returns (ERC1155Storage storage ts)
  {
    bytes32 position = keccak256("diamond.aave.v3.erc1155.storage");
    assembly {
      ts.slot := position
    }
  }

  function eip712Storage()
    internal
    pure
    returns (EIP712Storage storage es)
  {
    bytes32 position = keccak256("diamond.aave.v3.eip712.storage");
    assembly {
      es.slot := position
    }
  }

  function metaStorage()
    internal
    pure
    returns (MetaStorage storage ms)
  {
    bytes32 position = keccak256("diamond.aave.v3.meta.storage");
    assembly {
      ms.slot := position
    }
  }
}
