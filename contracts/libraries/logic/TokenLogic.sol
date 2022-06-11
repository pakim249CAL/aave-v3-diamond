// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { MetaLogic } from "@logic/MetaLogic.sol";
import { SupplyLogic } from "@logic/SupplyLogic.sol";
import { PoolLogic } from "@logic/PoolLogic.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { Errors } from "@helpers/Errors.sol";
import { WadRayMath } from "@math/WadRayMath.sol";
import { SafeCast } from "@dependencies/SafeCast.sol";
import { IERC20 } from "@interfaces/IERC20.sol";
import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";

/// @title ERC1155 Non-Compliant
/// @dev ERC1155 multi-token architecture is desired but external calls and hooks are too much to keep track of for me for re-entry reasons, so they are removed.

library TokenLogic {
  using SafeCast for uint256;
  using WadRayMath for uint256;
  using GPv2SafeERC20 for IERC20;

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

  function ts()
    internal
    pure
    returns (LibStorage.TokenStorage storage)
  {
    return LibStorage.tokenStorage();
  }

  function ps()
    internal
    pure
    returns (LibStorage.PoolStorage storage)
  {
    return LibStorage.poolStorage();
  }

  function msgSender() internal view returns (address) {
    return MetaLogic.msgSender();
  }

  function aTokenTransferFrom(
    address _from,
    address _to,
    uint256 _reserveId,
    uint256 _amount
  ) internal {
    _scaledTransfer(
      ts().aTokenBalances,
      _from,
      _to,
      _reserveId,
      _amount
    );
  }

  function _scaledTransfer(
    mapping(uint256 => mapping(address => DataTypes.ScaledTokenBalance))
      storage userBalances,
    address _from,
    address _to,
    uint256 _reserveId,
    uint256 _amount
  ) internal {
    address underlyingAsset = ps().reservesList[_reserveId];

    uint256 index = ReserveLogic.getNormalizedIncome(
      ps().reserves[underlyingAsset]
    );

    uint256 fromBalanceBefore = uint256(
      userBalances[_reserveId][_from].balance
    ).rayMul(index);
    uint256 toBalanceBefore = uint256(
      userBalances[_reserveId][_to].balance
    ).rayMul(index);

    userBalances[_reserveId][_from].balance -= _amount.toUint128();
    userBalances[_reserveId][_to].balance += _amount.toUint128();

    SupplyLogic.executeFinalizeTransfer(
      DataTypes.FinalizeTransferParams({
        asset: ps().reservesList[_reserveId],
        from: _from,
        to: _to,
        amount: _amount,
        balanceFromBefore: fromBalanceBefore,
        balanceToBefore: toBalanceBefore
      })
    );

    emit TransferSingle(msgSender(), _from, _to, _reserveId, _amount);
  }

  function aTokenMint(
    address _onBehalfOf,
    uint256 _reserveId,
    uint256 _amount,
    uint256 _index
  ) internal {
    _mintScaled(
      ts().aTokenBalances,
      ts().aTokenTotalSupply,
      _onBehalfOf,
      _reserveId,
      _amount,
      _index
    );
  }

  function _mintScaled(
    mapping(uint256 => mapping(address => DataTypes.ScaledTokenBalance))
      storage userBalances,
    mapping(uint256 => uint128) storage totalSupply,
    address _user,
    uint256 _reserveId,
    uint256 _amount,
    uint256 _index
  ) internal returns (bool) {
    DataTypes.ScaledTokenBalance storage balance = userBalances[
      _reserveId
    ][_user];
    uint256 amountScaled = _amount.rayDiv(_index);
    require(amountScaled != 0, Errors.INVALID_MINT_AMOUNT);

    uint256 scaledBalance = balance.balance;
    uint256 balanceIncrease = scaledBalance.rayMul(_index) -
      scaledBalance.rayMul(balance.prevIndex);

    balance.prevIndex = _index.toUint128();

    balance.balance += amountScaled.toUint128();
    totalSupply[_reserveId] += amountScaled.toUint128();

    uint256 amountToMint = _amount + balanceIncrease;
    emit TransferSingle(
      msgSender(),
      address(0),
      _user,
      _reserveId,
      amountToMint
    );

    return (scaledBalance == 0);
  }

  function aTokenBurn(
    address from,
    address receiverOfUnderlying,
    uint256 reserveId,
    uint256 amount,
    uint256 index
  ) internal {
    _burnScaled(
      ts().aTokenBalances,
      ts().aTokenTotalSupply,
      from,
      reserveId,
      amount,
      index
    );
    if (receiverOfUnderlying != address(this)) {
      IERC20(ps().reservesList[reserveId]).safeTransfer(
        receiverOfUnderlying,
        amount
      );
    }
  }

  /**
   * @notice Implements the basic logic to burn a scaled balance token.
   * @dev In some instances, a burn transaction will emit a mint event
   * if the amount to burn is less than the interest that the user accrued
   * @param user The user which debt is burnt
   * @param amount The amount getting burned
   * @param index The variable debt index of the reserve
   **/
  function _burnScaled(
    mapping(uint256 => mapping(address => DataTypes.ScaledTokenBalance))
      storage userBalances,
    mapping(uint256 => uint128) storage totalSupply,
    address user,
    uint256 reserveId,
    uint256 amount,
    uint256 index
  ) internal {
    DataTypes.ScaledTokenBalance storage userBalance = userBalances[
      reserveId
    ][user];
    uint256 amountScaled = amount.rayDiv(index);
    require(amountScaled != 0, Errors.INVALID_BURN_AMOUNT);

    userBalance.prevIndex = index.toUint128();

    userBalance.balance -= amountScaled.toUint128();
    totalSupply[reserveId] -= amountScaled.toUint128();

    emit TransferSingle(
      msgSender(),
      user,
      address(0),
      reserveId,
      amountScaled
    );
  }
}