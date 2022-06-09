// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { EIP712Logic } from "@logic/EIP712Logic.sol";
import { DataTypes } from "@types/DataTypes.sol";

library MetaLogic {
  function ms()
    internal
    pure
    returns (LibStorage.MetaStorage storage)
  {
    return LibStorage.metaStorage();
  }

  bytes32 private constant META_TRANSACTION_TYPEHASH =
    keccak256(
      bytes(
        "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
      )
    );

  function msgSender() internal view returns (address sender_) {
    if (msg.sender == address(this)) {
      bytes memory array = msg.data;
      uint256 index = msg.data.length;
      assembly {
        // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
        sender_ := and(
          mload(add(array, index)),
          0xffffffffffffffffffffffffffffffffffffffff
        )
      }
    } else {
      sender_ = msg.sender;
    }
  }

  function convertBytesToBytes4(bytes memory inBytes)
    internal
    pure
    returns (bytes4 outBytes4)
  {
    if (inBytes.length == 0) {
      return 0x0;
    }

    assembly {
      outBytes4 := mload(add(inBytes, 32))
    }
  }

  /**
   * Accept message hash and returns hash message in EIP712 compatible form
   * So that it can be used to recover signer from signature signed using EIP712 formatted data
   * https://eips.ethereum.org/EIPS/eip-712
   * "\\x19" makes the encoding deterministic
   * "\\x01" is the version byte to make it compatible to EIP-191
   */
  function toTypedMessageHash(bytes32 messageHash)
    internal
    view
    returns (bytes32)
  {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          EIP712Logic.domainSeparator(),
          messageHash
        )
      );
  }

  function hashMetaTransaction(
    DataTypes.MetaTransaction memory metaTx
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          META_TRANSACTION_TYPEHASH,
          metaTx.nonce,
          metaTx.from,
          keccak256(metaTx.functionSignature)
        )
      );
  }

  function verify(
    address user,
    DataTypes.MetaTransaction memory metaTx,
    bytes32 sigR,
    bytes32 sigS,
    uint8 sigV
  ) internal view returns (bool) {
    address signer = ecrecover(
      toTypedMessageHash(hashMetaTransaction(metaTx)),
      sigV,
      sigR,
      sigS
    );
    require(signer != address(0), "Invalid signature");
    return signer == user;
  }
}
