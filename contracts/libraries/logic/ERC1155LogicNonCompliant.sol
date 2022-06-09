// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";

library ERC1155LogicNonCompliant {
  event TransferSingle(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256 id,
    uint256 value
  );

  event TransferBatch(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256[] ids,
    uint256[] values
  );

  event ApprovalForAll(
    address indexed account,
    address indexed operator,
    bool approved
  );

  function ts() internal pure returns (LibStorage.ERC1155 storage) {
    return LibStorage.tokenStorage();
  }

  function balanceOf(address account, uint256 id)
    internal
    view
    returns (uint256)
  {
    require(
      account != address(0),
      "ERC1155LogicNonCompliant: balance query for the zero address"
    );
    return ts().balances[id][account];
  }

  function balanceOfBatch(
    address[] memory accounts,
    uint256[] memory ids
  ) internal view returns (uint256[] memory) {
    require(
      accounts.length == ids.length,
      "ERC1155: accounts and ids length mismatch"
    );

    uint256[] memory batchBalances = new uint256[](accounts.length);

    for (uint256 i = 0; i < accounts.length; ++i) {
      batchBalances[i] = balanceOf(accounts[i], ids[i]);
    }

    return batchBalances;
  }

  function isApprovedForAll(address account, address operator)
    internal
    view
    returns (bool)
  {
    return ts().operatorApprovals[account][operator];
  }

  // Removed before and after hooks
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount
  ) internal {
    require(
      to != address(0),
      "ERC1155: transfer to the zero address"
    );

    address operator = msg.sender;

    uint256 fromBalance = ts().balances[id][from];
    require(
      fromBalance >= amount,
      "ERC1155: insufficient balance for transfer"
    );
    unchecked {
      ts().balances[id][from] = fromBalance - amount;
    }
    ts().balances[id][to] += amount;

    emit TransferSingle(operator, from, to, id, amount);
  }

  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
  ) internal {
    require(
      ids.length == amounts.length,
      "ERC1155: ids and amounts length mismatch"
    );
    require(
      to != address(0),
      "ERC1155: transfer to the zero address"
    );

    address operator = msg.sender;

    for (uint256 i = 0; i < ids.length; ++i) {
      uint256 id = ids[i];
      uint256 amount = amounts[i];

      uint256 fromBalance = ts().balances[id][from];
      require(
        fromBalance >= amount,
        "ERC1155: insufficient balance for transfer"
      );
      unchecked {
        ts().balances[id][from] = fromBalance - amount;
      }
      ts().balances[id][to] += amount;
    }

    emit TransferBatch(operator, from, to, ids, amounts);
  }

  function mint(
    address to,
    uint256 id,
    uint256 amount
  ) internal {
    require(to != address(0), "ERC1155: mint to the zero address");

    address operator = msg.sender;

    ts().balances[id][to] += amount;
    emit TransferSingle(operator, address(0), to, id, amount);
  }

  function mintBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
  ) internal {
    require(to != address(0), "ERC1155: mint to the zero address");
    require(
      ids.length == amounts.length,
      "ERC1155: ids and amounts length mismatch"
    );

    address operator = msg.sender;

    for (uint256 i = 0; i < ids.length; i++) {
      ts().balances[ids[i]][to] += amounts[i];
    }

    emit TransferBatch(operator, address(0), to, ids, amounts);
  }

  function burn(
    address from,
    uint256 id,
    uint256 amount
  ) internal {
    require(
      from != address(0),
      "ERC1155: burn from the zero address"
    );

    address operator = msg.sender;

    uint256 fromBalance = ts().balances[id][from];
    require(
      fromBalance >= amount,
      "ERC1155: burn amount exceeds balance"
    );
    unchecked {
      ts().balances[id][from] = fromBalance - amount;
    }

    emit TransferSingle(operator, from, address(0), id, amount);
  }

  function burnBatch(
    address from,
    uint256[] memory ids,
    uint256[] memory amounts
  ) internal {
    require(
      from != address(0),
      "ERC1155: burn from the zero address"
    );
    require(
      ids.length == amounts.length,
      "ERC1155: ids and amounts length mismatch"
    );

    address operator = msg.sender;

    for (uint256 i = 0; i < ids.length; i++) {
      uint256 id = ids[i];
      uint256 amount = amounts[i];

      uint256 fromBalance = ts().balances[id][from];
      require(
        fromBalance >= amount,
        "ERC1155: burn amount exceeds balance"
      );
      unchecked {
        ts().balances[id][from] = fromBalance - amount;
      }
    }

    emit TransferBatch(operator, from, address(0), ids, amounts);
  }

  function setApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) internal {
    require(
      owner != operator,
      "ERC1155: setting approval status for self"
    );
    ts().operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }
}
