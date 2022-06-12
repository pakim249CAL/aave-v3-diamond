// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from "../libraries/LibDiamond.sol";

contract FunctionSelectorEntry {
  function addDiamondFunctions(
    address _facetAddress,
    bytes4[] memory _functionSelectors
  ) external {
    LibDiamond.enforceIsContractOwner();
    LibDiamond.addFunctions(_facetAddress, _functionSelectors);
  }

  function replaceDiamondFunctions(
    address _facetAddress,
    bytes4[] memory _functionSelectors
  ) external {
    LibDiamond.enforceIsContractOwner();
    LibDiamond.replaceFunctions(_facetAddress, _functionSelectors);
  }

  function removeDiamondFunctions(bytes4[] memory _functionSelectors)
    external
  {
    LibDiamond.enforceIsContractOwner();
    LibDiamond.removeFunctions(address(0), _functionSelectors);
  }

  function arbitraryDelegateCall(
    address _contract,
    bytes calldata _calldata
  ) external {
    LibDiamond.enforceIsContractOwner();
    LibDiamond.initializeDiamondCut(_contract, _calldata);
  }
}
