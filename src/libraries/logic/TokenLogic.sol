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
import { MathUtils } from "@math/MathUtils.sol";

import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";
import { SafeCast } from "@dependencies/SafeCast.sol";

import { IERC20 } from "@interfaces/IERC20.sol";

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

  function totalSupplyAToken(uint256 _reserveId)
    internal
    view
    returns (uint256)
  {
    DataTypes.ReserveData storage reserve = ps().reserves[
      ps().reservesList[_reserveId]
    ];
    return
      uint256(ts().aTokenTotalSupply[_reserveId]).rayMul(
        ReserveLogic.getNormalizedIncome(reserve)
      );
  }

  function totalSupplyVariableDebt(uint256 _reserveId)
    internal
    view
    returns (uint256)
  {
    DataTypes.ReserveData storage reserve = ps().reserves[
      ps().reservesList[_reserveId]
    ];
    return
      uint256(ts().variableDebtTotalSupply[_reserveId]).rayMul(
        ReserveLogic.getNormalizedDebt(reserve)
      );
  }

  /**
   * @notice Calculates the total supply
   * @return The debt balance of the user since the last burn/mint action
   **/
  function totalSupplyStableDebt(uint256 _reserveId)
    internal
    view
    returns (uint256)
  {
    uint256 principalSupply = ts().stableDebtTotalSupply[_reserveId];

    if (principalSupply == 0) {
      return 0;
    }

    uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(
      ts().avgStableRate[_reserveId],
      ts().stableDebtTotalSupplyTimestamp[_reserveId]
    );

    return principalSupply.rayMul(cumulatedInterest);
  }

  function balanceOfAToken(uint256 _reserveId, address _user)
    internal
    view
    returns (uint256)
  {
    return
      uint256(ts().aTokenBalances[_reserveId][_user].balance).rayMul(
        ReserveLogic.getNormalizedIncome(
          ps().reserves[ps().reservesList[_reserveId]]
        )
      );
  }

  function balanceOfVariableDebt(uint256 _reserveId, address _user)
    internal
    view
    returns (uint256)
  {
    return
      uint256(ts().variableDebtBalances[_reserveId][_user].balance)
        .rayMul(
          ReserveLogic.getNormalizedDebt(
            ps().reserves[ps().reservesList[_reserveId]]
          )
        );
  }

  function balanceOfStableDebt(uint256 _reserveId, address _user)
    internal
    view
    returns (uint256)
  {
    uint256 accountBalance = uint256(
      ts().stableDebtBalances[_reserveId][_user].balance
    );
    uint256 stableRate = ts()
    .stableDebtBalances[_reserveId][_user].prevIndex;
    if (accountBalance == 0) {
      return 0;
    }
    uint256 cumulatedInterest = MathUtils.calculateCompoundedInterest(
      stableRate,
      ts().stableDebtTimestamps[_reserveId][_user]
    );
    return accountBalance.rayMul(cumulatedInterest);
  }

  function getSupplyDataStableDebt(uint256 _reserveId)
    internal
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint40
    )
  {
    uint256 avgRate = ts().avgStableRate[_reserveId];
    return (
      ts().stableDebtTotalSupply[_reserveId],
      totalSupplyStableDebt(_reserveId),
      avgRate,
      ts().stableDebtTotalSupplyTimestamp[_reserveId]
    );
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
  ) internal returns (bool) {
    return
      _mintScaled(
        ts().aTokenBalances,
        ts().aTokenTotalSupply,
        _onBehalfOf,
        _reserveId,
        _amount,
        _index
      );
  }

  function variableDebtTokenMint(
    address _onBehalfOf,
    uint256 _reserveId,
    uint256 _amount,
    uint256 _index
  ) internal returns (bool, uint256) {
    if (msgSender() != _onBehalfOf) {
      ts().variableBorrowAllowances[_reserveId][_onBehalfOf][
          msgSender()
        ] -= _amount;
    }
    return (
      _mintScaled(
        ts().variableDebtBalances,
        ts().variableDebtTotalSupply,
        _onBehalfOf,
        _reserveId,
        _amount,
        _index
      ),
      ts().variableDebtTotalSupply[_reserveId]
    );
  }

  struct StableDebtMintLocalVars {
    uint256 previousSupply;
    uint256 nextSupply;
    uint256 amountInRay;
    uint256 currentStableRate;
    uint256 nextStableRate;
    uint256 currentAvgStableRate;
  }

  function stableDebtTokenMint(
    address _onBehalfOf,
    uint256 _reserveId,
    uint256 _amount,
    uint256 _index
  )
    internal
    returns (
      bool,
      uint256,
      uint256
    )
  {
    StableDebtMintLocalVars memory vars;

    if (msgSender() != _onBehalfOf) {
      ts().stableBorrowAllowances[_reserveId][_onBehalfOf][
          msgSender()
        ] -= _amount;
    }

    (
      ,
      uint256 currentBalance,
      uint256 balanceIncrease
    ) = _calculateStableDebtBalanceIncrease(_reserveId, _onBehalfOf);

    vars.currentAvgStableRate = ts().avgStableRate[_reserveId];
    vars.previousSupply = totalSupplyStableDebt(_reserveId);
    vars.nextSupply = ts().stableDebtTotalSupply[_reserveId] = (vars
      .previousSupply + _amount).toUint128();

    vars.amountInRay = _amount.wadToRay();

    vars.currentStableRate = ts()
    .stableDebtBalances[_reserveId][_onBehalfOf].prevIndex;
    vars.nextStableRate = (vars.currentStableRate.rayMul(
      currentBalance.wadToRay()
    ) + vars.amountInRay.rayMul(_index)).rayDiv(
        (currentBalance + _amount).wadToRay()
      );

    ts().stableDebtBalances[_reserveId][_onBehalfOf].prevIndex = vars
      .nextStableRate
      .toUint128();

    //solium-disable-next-line
    ts().stableDebtTotalSupplyTimestamp[_reserveId] = ts()
      .stableDebtTimestamps[_reserveId][_onBehalfOf] = uint40(
      block.timestamp
    );

    // Calculates the updated average stable rate
    vars.currentAvgStableRate = ts().avgStableRate[_reserveId] = (
      (vars.currentAvgStableRate.rayMul(
        vars.previousSupply.wadToRay()
      ) + _index.rayMul(vars.amountInRay)).rayDiv(
          vars.nextSupply.wadToRay()
        )
    ).toUint128();

    uint256 amountToMint = _amount + balanceIncrease;
    ts()
    .stableDebtBalances[_reserveId][_onBehalfOf]
      .balance += amountToMint.toUint128();

    emit TransferSingle(
      msgSender(),
      address(0),
      _onBehalfOf,
      _reserveId,
      amountToMint
    );

    return (
      currentBalance == 0,
      vars.nextSupply,
      vars.currentAvgStableRate
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
    DataTypes.ScaledTokenBalance storage userBalance = userBalances[
      _reserveId
    ][_user];
    uint256 amountScaled = _amount.rayDiv(_index);
    require(amountScaled != 0, Errors.INVALID_MINT_AMOUNT);

    uint256 scaledBalance = userBalance.balance;
    uint256 balanceIncrease = scaledBalance.rayMul(_index) -
      scaledBalance.rayMul(userBalance.prevIndex);

    userBalance.balance += amountScaled.toUint128();
    userBalance.prevIndex = _index.toUint128();
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

  function variableDebtTokenBurn(
    address _from,
    uint256 _reserveId,
    uint256 _amount,
    uint256 _index
  ) internal returns (uint256) {
    _burnScaled(
      ts().variableDebtBalances,
      ts().variableDebtTotalSupply,
      _from,
      _reserveId,
      _amount,
      _index
    );
    return ts().variableDebtTotalSupply[_reserveId];
  }

  function stableDebtTokenBurn(
    address _from,
    uint256 _reserveId,
    uint256 _amount
  ) internal returns (uint256, uint256) {
    (
      ,
      uint256 currentBalance,
      uint256 balanceIncrease
    ) = _calculateStableDebtBalanceIncrease(_reserveId, _from);

    uint256 previousSupply = totalSupplyStableDebt(_reserveId);
    uint256 nextAvgStableRate = 0;
    uint256 nextSupply = 0;
    uint256 userStableRate = ts()
    .stableDebtBalances[_reserveId][_from].prevIndex;

    // Since the total supply and each single user debt accrue separately,
    // there might be accumulation errors so that the last borrower repaying
    // might actually try to repay more than the available debt supply.
    // In this case we simply set the total supply and the avg stable rate to 0
    if (previousSupply <= _amount) {
      ts().avgStableRate[_reserveId] = 0;
      ts().stableDebtTotalSupply[_reserveId] = 0;
    } else {
      nextSupply = ts().stableDebtTotalSupply[
        _reserveId
      ] = (previousSupply - _amount).toUint128();
      uint256 firstTerm = uint256(ts().avgStableRate[_reserveId])
        .rayMul(previousSupply.wadToRay());
      uint256 secondTerm = userStableRate.rayMul(_amount.wadToRay());

      // For the same reason described above, when the last user is repaying it might
      // happen that user rate * user balance > avg rate * total supply. In that case,
      // we simply set the avg rate to 0
      if (secondTerm >= firstTerm) {
        nextAvgStableRate = ts().stableDebtTotalSupply[
          _reserveId
        ] = ts().avgStableRate[_reserveId] = 0;
      } else {
        nextAvgStableRate = ts().avgStableRate[_reserveId] = (
          (firstTerm - secondTerm).rayDiv(nextSupply.wadToRay())
        ).toUint128();
      }
    }

    if (_amount == currentBalance) {
      ts().stableDebtBalances[_reserveId][_from].prevIndex = 0;
      ts().stableDebtTimestamps[_reserveId][_from] = 0;
    } else {
      //solium-disable-next-line
      ts().stableDebtTimestamps[_reserveId][_from] = uint40(
        block.timestamp
      );
    }
    //solium-disable-next-line
    ts().stableDebtTotalSupplyTimestamp[_reserveId] = uint40(
      block.timestamp
    );

    if (balanceIncrease > _amount) {
      uint256 amountToMint = balanceIncrease - _amount;
      ts()
      .stableDebtBalances[_reserveId][_from].balance += amountToMint
        .toUint128();
      emit TransferSingle(
        msgSender(),
        address(0),
        _from,
        _reserveId,
        amountToMint
      );
    } else {
      uint256 amountToBurn = _amount - balanceIncrease;
      ts()
      .stableDebtBalances[_reserveId][_from].balance -= amountToBurn
        .toUint128();
      emit TransferSingle(
        msgSender(),
        _from,
        address(0),
        _reserveId,
        amountToBurn
      );
    }

    return (nextSupply, nextAvgStableRate);
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

  /**
   * @notice Calculates the increase in balance since the last user interaction
   * @return The previous principal balance
   * @return The new principal balance
   * @return The balance increase
   **/
  function _calculateStableDebtBalanceIncrease(
    uint256 _reserveId,
    address _user
  )
    internal
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    uint256 previousPrincipalBalance = ts()
    .stableDebtBalances[_reserveId][_user].balance;

    if (previousPrincipalBalance == 0) {
      return (0, 0, 0);
    }

    uint256 newPrincipalBalance = balanceOfStableDebt(
      _reserveId,
      _user
    );

    return (
      previousPrincipalBalance,
      newPrincipalBalance,
      newPrincipalBalance - previousPrincipalBalance
    );
  }
}
