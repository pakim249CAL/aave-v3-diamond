// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Script.sol";

import { Diamond } from "@diamond/Diamond.sol";
import { FunctionSelectorEntry } from "@diamond/facets/FunctionSelectorEntry.sol";
import { FunctionLens } from "@diamond/facets/FunctionLens.sol";
import { OwnershipEntry } from "@diamond/facets/OwnershipEntry.sol";
import { BorrowEntry } from "@facets/BorrowEntry.sol";
import { SupplyEntry } from "@facets/SupplyEntry.sol";
import { LiquidationEntry } from "@facets/LiquidationEntry.sol";
import { Lens } from "@facets/Lens.sol";
import { InitMarket } from "@init/InitMarket.sol";

contract DeploymentScript is Script {
  function run() external {
    vm.startBroadcast();

    address functionSelectorEntry = address(
      new FunctionSelectorEntry()
    );
    address functionLens = address(new FunctionLens());
    address ownershipEntry = address(new OwnershipEntry());
    address borrowEntry = address(new BorrowEntry());
    address supplyEntry = address(new SupplyEntry());
    address liquidationEntry = address(new LiquidationEntry());
    address lens = address(new Lens());
    address initMarket = address(new InitMarket());

    address diamond = address(
      new Diamond(
        0x8FEebfA4aC7AF314d90a0c17C3F91C800cFdE44B,
        functionSelectorEntry
      )
    );

    FunctionSelectorEntry(diamond).arbitraryDelegateCall(
      initMarket,
      abi.encodeWithSelector(
        InitMarket.initAll.selector,
        InitMarket.DeployedAddresses({
          functionLens: functionLens,
          ownershipEntry: ownershipEntry,
          borrowEntry: borrowEntry,
          supplyEntry: supplyEntry,
          liquidationEntry: liquidationEntry,
          lens: lens
        })
      )
    );

    vm.stopBroadcast();
  }
}
