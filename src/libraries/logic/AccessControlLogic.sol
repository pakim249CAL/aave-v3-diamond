// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";

library AccessControlLogic {
  bytes32 private constant FLASH_BORROWER_ROLE =
    keccak256("FLASH_BORROWER");

  function rs()
    internal
    pure
    returns (LibStorage.RoleStorage storage)
  {
    return LibStorage.roleStorage();
  }

  function isFlashBorrower(address _user)
    internal
    view
    returns (bool)
  {
    return _hasRole(FLASH_BORROWER_ROLE, _user);
  }

  function _hasRole(bytes32 role, address account)
    internal
    view
    returns (bool)
  {
    return rs().roles[role].members[account];
  }
}
