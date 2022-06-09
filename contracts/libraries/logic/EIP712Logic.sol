// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@storage/LibStorage.sol";
import "@dependencies/ECDSA.sol";

library EIP712Logic {
  function s()
    private
    pure
    returns (LibStorage.EIP712Storage storage)
  {
    return LibStorage.eip712Storage();
  }

  function domainSeparator() internal view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /**
   * @dev Returns the domain separator for the current chain.
   */
  function _domainSeparatorV4() internal view returns (bytes32) {
    if (block.chainid == s().CACHED_CHAIN_ID) {
      return s().CACHED_DOMAIN_SEPARATOR;
    } else {
      return
        _buildDomainSeparator(
          s().TYPE_HASH,
          s().HASHED_NAME,
          s().HASHED_VERSION
        );
    }
  }

  function _buildDomainSeparator(
    bytes32 typeHash,
    bytes32 nameHash,
    bytes32 versionHash
  ) internal view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          typeHash,
          nameHash,
          versionHash,
          block.chainid,
          address(this)
        )
      );
  }

  /**
   * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
   * function returns the hash of the fully encoded EIP712 message for this domain.
   *
   * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
   *
   * ```solidity
   * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
   *     keccak256("Mail(address to,string contents)"),
   *     mailTo,
   *     keccak256(bytes(mailContents))
   * )));
   * address signer = ECDSA.recover(digest, signature);
   * ```
   */
  function _hashTypedDataV4(bytes32 structHash)
    internal
    view
    returns (bytes32)
  {
    return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
  }
}
