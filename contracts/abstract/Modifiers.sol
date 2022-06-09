// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { LibDiamond } from "@diamond/libraries/LibDiamond.sol";
import { LibStorage } from "@storage/LibStorage.sol";
import { MetaLogic } from "@logic/MetaLogic.sol";
import { Strings } from "@dependencies/Strings.sol";

/**
 * @title Utility contract for preventing reentrancy attacks
 */
abstract contract Modifiers {
  bytes32 private constant POOL_ADMIN_ROLE = keccak256("POOL_ADMIN");
  bytes32 private constant EMERGENCY_ADMIN_ROLE =
    keccak256("EMERGENCY_ADMIN");
  bytes32 private constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN");
  bytes32 private constant FLASH_BORROWER_ROLE =
    keccak256("FLASH_BORROWER");
  bytes32 private constant BRIDGE_ROLE = keccak256("BRIDGE");
  bytes32 private constant ASSET_LISTING_ADMIN_ROLE =
    keccak256("ASSET_LISTING_ADMIN");

  // STORAGE
  function rs()
    internal
    pure
    returns (LibStorage.RoleStorage storage)
  {
    return LibStorage.roleStorage();
  }

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

  modifier onlyOwner() {
    LibDiamond.enforceIsContractOwner();
    _;
  }

  modifier onlyRole(bytes32 role) {
    address sender = msgSender();
    if (!_hasRole(role, sender))
      revert(
        string(
          abi.encodePacked(
            "Modifiers: account ",
            Strings.toHexString(uint160(sender), 20),
            " is missing role ",
            Strings.toHexString(uint256(role), 32)
          )
        )
      );
    _;
  }

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   **/
  modifier onlyPoolAdmin() {
    address sender = msgSender();
    if (!_hasRole(POOL_ADMIN_ROLE, sender))
      revert(
        string(
          abi.encodePacked(
            "Modifiers: account ",
            Strings.toHexString(uint160(sender), 20),
            " is missing role ",
            Strings.toHexString(uint256(POOL_ADMIN_ROLE), 32)
          )
        )
      );
    _;
  }

  /**
   * @dev Only emergency admin can call functions marked by this modifier.
   **/
  modifier onlyEmergencyAdmin() {
    address sender = msgSender();
    if (!_hasRole(EMERGENCY_ADMIN_ROLE, sender))
      revert(
        string(
          abi.encodePacked(
            "Modifiers: account ",
            Strings.toHexString(uint160(sender), 20),
            " is missing role ",
            Strings.toHexString(uint256(EMERGENCY_ADMIN_ROLE), 32)
          )
        )
      );
    _;
  }

  /**
   * @dev Only emergency or pool admin can call functions marked by this modifier.
   **/
  modifier onlyEmergencyOrPoolAdmin() {
    address sender = msgSender();
    if (
      !_hasRole(POOL_ADMIN_ROLE, sender) &&
      !_hasRole(EMERGENCY_ADMIN_ROLE, sender)
    )
      revert(
        string(
          abi.encodePacked(
            "Modifiers: account ",
            Strings.toHexString(uint160(sender), 20),
            " is missing role ",
            Strings.toHexString(uint256(EMERGENCY_ADMIN_ROLE), 32),
            " and ",
            Strings.toHexString(uint256(POOL_ADMIN_ROLE), 32)
          )
        )
      );
    _;
  }

  /**
   * @dev Only asset listing or pool admin can call functions marked by this modifier.
   **/
  modifier onlyAssetListingOrPoolAdmins() {
    address sender = msgSender();
    if (
      !_hasRole(POOL_ADMIN_ROLE, sender) &&
      !_hasRole(ASSET_LISTING_ADMIN_ROLE, sender)
    )
      revert(
        string(
          abi.encodePacked(
            "Modifiers: account ",
            Strings.toHexString(uint160(sender), 20),
            " is missing role ",
            Strings.toHexString(
              uint256(ASSET_LISTING_ADMIN_ROLE),
              32
            ),
            " and ",
            Strings.toHexString(uint256(POOL_ADMIN_ROLE), 32)
          )
        )
      );
    _;
  }

  /**
   * @dev Only risk or pool admin can call functions marked by this modifier.
   **/
  modifier onlyRiskOrPoolAdmins() {
    address sender = msgSender();
    if (
      !_hasRole(POOL_ADMIN_ROLE, sender) &&
      !_hasRole(RISK_ADMIN_ROLE, sender)
    )
      revert(
        string(
          abi.encodePacked(
            "Modifiers: account ",
            Strings.toHexString(uint160(sender), 20),
            " is missing role ",
            Strings.toHexString(uint256(RISK_ADMIN_ROLE), 32),
            " and ",
            Strings.toHexString(uint256(POOL_ADMIN_ROLE), 32)
          )
        )
      );
    _;
  }

  /**
   * @dev Only bridge can call functions marked by this modifier.
   **/
  modifier onlyBridge() {
    address sender = msgSender();
    if (!_hasRole(BRIDGE_ROLE, sender))
      revert(
        string(
          abi.encodePacked(
            "Modifiers: account ",
            Strings.toHexString(uint160(sender), 20),
            " is missing role ",
            Strings.toHexString(uint256(BRIDGE_ROLE), 32)
          )
        )
      );
    _;
  }

  function _hasRole(bytes32 role, address account)
    internal
    view
    returns (bool)
  {
    return rs().roles[role].members[account];
  }

  function msgSender() internal view returns (address) {
    return MetaLogic.msgSender();
  }

  function _msgData() internal view returns (bytes memory) {
    this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    return msg.data;
  }
}
