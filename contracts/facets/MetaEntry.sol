// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { Modifiers } from "@abstract/Modifiers.sol";
import { MetaLogic } from "@logic/MetaLogic.sol";
import { LibStorage } from "@storage/LibStorage.sol";
import { DataTypes } from "@types/DataTypes.sol";

contract MetaEntry is Modifiers {
  event MetaTransactionExecuted(
    address userAddress,
    address payable relayerAddress,
    bytes functionSignature
  );

  function ms()
    internal
    pure
    returns (LibStorage.MetaStorage storage)
  {
    return LibStorage.metaStorage();
  }

  function executeMetaTransaction(
    address userAddress,
    bytes memory functionSignature,
    bytes32 sigR,
    bytes32 sigS,
    uint8 sigV
  ) public payable returns (bytes memory) {
    bytes4 destinationFunctionSig = MetaLogic.convertBytesToBytes4(
      functionSignature
    );
    require(
      destinationFunctionSig != msg.sig,
      "functionSignature can not be of executeMetaTransaction method"
    );
    uint256 nonce = ms().nonces[userAddress];
    DataTypes.MetaTransaction memory metaTx = DataTypes
      .MetaTransaction({
        nonce: nonce,
        from: userAddress,
        functionSignature: functionSignature
      });
    require(
      MetaLogic.verify(userAddress, metaTx, sigR, sigS, sigV),
      "Signer and signature do not match"
    );
    ms().nonces[userAddress]++;
    // Append userAddress at the end to extract it from calling context
    (bool success, bytes memory returnData) = address(this).call(
      abi.encodePacked(functionSignature, userAddress)
    );

    require(success, "Function call not successful");
    emit MetaTransactionExecuted(
      userAddress,
      payable(msg.sender),
      functionSignature
    );
    return returnData;
  }
}
