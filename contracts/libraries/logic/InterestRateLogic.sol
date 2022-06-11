// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { PercentageMath } from "@math/PercentageMath.sol";
import { WadRayMath } from "@math/WadRayMath.sol";
import { IERC20 } from "@interfaces/IERC20.sol";

library InterestRateLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct CalcInterestRatesLocalVars {
    uint256 availableLiquidity;
    uint256 totalDebt;
    uint256 currentVariableBorrowRate;
    uint256 currentStableBorrowRate;
    uint256 currentLiquidityRate;
    uint256 borrowUsageRatio;
    uint256 supplyUsageRatio;
    uint256 stableToTotalDebtRatio;
    uint256 availableLiquidityPlusDebt;
  }

  function irs()
    internal
    pure
    returns (LibStorage.InterestRateStorage storage)
  {
    return LibStorage.interestRateStorage();
  }

  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  )
    internal
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    CalcInterestRatesLocalVars memory vars;
    DataTypes.InterestRateStrategy memory strategy = irs()
      .interestRateStrategies[params.reserveId];

    vars.totalDebt =
      params.totalStableDebt +
      params.totalVariableDebt;

    vars.currentLiquidityRate = 0;
    vars.currentVariableBorrowRate = strategy.baseVariableBorrowRate;
    vars.currentStableBorrowRate = getBaseStableBorrowRate(
      params.reserveId
    );

    if (vars.totalDebt != 0) {
      vars.stableToTotalDebtRatio = params.totalStableDebt.rayDiv(
        vars.totalDebt
      );
      vars.availableLiquidity =
        IERC20(params.reserve).balanceOf(params.aToken) +
        params.liquidityAdded -
        params.liquidityTaken;

      vars.availableLiquidityPlusDebt =
        vars.availableLiquidity +
        vars.totalDebt;
      vars.borrowUsageRatio = vars.totalDebt.rayDiv(
        vars.availableLiquidityPlusDebt
      );
      vars.supplyUsageRatio = vars.totalDebt.rayDiv(
        vars.availableLiquidityPlusDebt + params.unbacked
      );
    }

    if (vars.borrowUsageRatio > strategy.OPTIMAL_USAGE_RATIO) {
      uint256 excessBorrowUsageRatio = (vars.borrowUsageRatio -
        strategy.OPTIMAL_USAGE_RATIO).rayDiv(
          strategy.MAX_EXCESS_USAGE_RATIO
        );

      vars.currentStableBorrowRate +=
        strategy.stableRateSlope1 +
        strategy.stableRateSlope2.rayMul(excessBorrowUsageRatio);

      vars.currentVariableBorrowRate +=
        strategy.variableRateSlope1 +
        strategy.variableRateSlope2.rayMul(excessBorrowUsageRatio);
    } else {
      vars.currentStableBorrowRate += strategy
        .stableRateSlope1
        .rayMul(vars.borrowUsageRatio)
        .rayDiv(strategy.OPTIMAL_USAGE_RATIO);

      vars.currentVariableBorrowRate += strategy
        .variableRateSlope1
        .rayMul(vars.borrowUsageRatio)
        .rayDiv(strategy.OPTIMAL_USAGE_RATIO);
    }

    if (
      vars.stableToTotalDebtRatio >
      strategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO
    ) {
      uint256 excessStableDebtRatio = (vars.stableToTotalDebtRatio -
        strategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO).rayDiv(
          strategy.MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO
        );
      vars.currentStableBorrowRate += strategy
        .stableRateExcessOffset
        .rayMul(excessStableDebtRatio);
    }

    vars.currentLiquidityRate = getOverallBorrowRate(
      params.totalStableDebt,
      params.totalVariableDebt,
      vars.currentVariableBorrowRate,
      params.averageStableBorrowRate
    ).rayMul(vars.supplyUsageRatio).percentMul(
        PercentageMath.PERCENTAGE_FACTOR - params.reserveFactor
      );

    return (
      vars.currentLiquidityRate,
      vars.currentStableBorrowRate,
      vars.currentVariableBorrowRate
    );
  }

  /**
   * @dev Calculates the overall borrow rate as the weighted average between the total variable debt and total stable
   * debt
   * @param totalStableDebt The total borrowed from the reserve at a stable rate
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param currentVariableBorrowRate The current variable borrow rate of the reserve
   * @param currentAverageStableBorrowRate The current weighted average of all the stable rate loans
   * @return The weighted averaged borrow rate
   **/
  function getOverallBorrowRate(
    uint256 totalStableDebt,
    uint256 totalVariableDebt,
    uint256 currentVariableBorrowRate,
    uint256 currentAverageStableBorrowRate
  ) internal pure returns (uint256) {
    uint256 totalDebt = totalStableDebt + totalVariableDebt;

    if (totalDebt == 0) return 0;

    uint256 weightedVariableRate = totalVariableDebt
      .wadToRay()
      .rayMul(currentVariableBorrowRate);

    uint256 weightedStableRate = totalStableDebt.wadToRay().rayMul(
      currentAverageStableBorrowRate
    );

    uint256 overallBorrowRate = (weightedVariableRate +
      weightedStableRate).rayDiv(totalDebt.wadToRay());

    return overallBorrowRate;
  }

  function getBaseStableBorrowRate(uint256 _strategyId)
    internal
    view
    returns (uint256)
  {
    return
      irs().interestRateStrategies[_strategyId].variableRateSlope1 +
      irs().interestRateStrategies[_strategyId].baseStableRateOffset;
  }
}
