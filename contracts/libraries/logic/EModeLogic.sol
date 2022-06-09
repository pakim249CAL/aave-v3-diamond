// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import { LibStorage } from "@storage/LibStorage.sol";
import { GPv2SafeERC20 } from "@dependencies/GPv2SafeERC20.sol";
import { IERC20 } from "@interfaces/IERC20.sol";
import { UserConfiguration } from "@configuration/UserConfiguration.sol";
import { Errors } from "@helpers/Errors.sol";
import { WadRayMath } from "@math/WadRayMath.sol";
import { PercentageMath } from "@math/PercentageMath.sol";
import { DataTypes } from "@types/DataTypes.sol";
import { ValidationLogic } from "@logic/ValidationLogic.sol";
import { ReserveLogic } from "@logic/ReserveLogic.sol";
import { OracleLogic } from "@logic/OracleLogic.sol";

/**
 * @title EModeLogic library
 * @author Aave
 * @notice Implements the base logic for all the actions related to the eMode
 */
library EModeLogic {
  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;
  using GPv2SafeERC20 for IERC20;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // See `IPool` for descriptions
  event UserEModeSet(address indexed user, uint8 categoryId);

  function ps()
    internal
    pure
    returns (LibStorage.PoolStorage storage)
  {
    return LibStorage.poolStorage();
  }

  /**
   * @notice Updates the user efficiency mode category
   * @dev Will revert if user is borrowing non-compatible asset or change will drop HF < HEALTH_FACTOR_LIQUIDATION_THRESHOLD
   * @dev Emits the `UserEModeSet` event
   * @param userConfig The user configuration mapping that tracks the supplied/borrowed assets
   * @param params The additional parameters needed to execute the setUserEMode function
   */
  function executeSetUserEMode(
    DataTypes.UserConfigurationMap storage userConfig,
    DataTypes.ExecuteSetUserEModeParams memory params
  ) internal {
    ValidationLogic.validateSetUserEMode(
      userConfig,
      params.reservesCount,
      params.categoryId
    );

    uint8 prevCategoryId = ps().usersEModeCategory[msg.sender];
    ps().usersEModeCategory[msg.sender] = params.categoryId;

    if (prevCategoryId != 0) {
      ValidationLogic.validateHealthFactor(
        userConfig,
        msg.sender,
        params.categoryId,
        params.reservesCount
      );
    }
    emit UserEModeSet(msg.sender, params.categoryId);
  }

  /**
   * @notice Gets the eMode configuration and calculates the eMode asset price if a custom oracle is configured
   * @dev The eMode asset price returned is 0 if no oracle is specified
   * @param category The user eMode category
   * @return The eMode ltv
   * @return The eMode liquidation threshold
   * @return The eMode asset price
   **/
  function getEModeConfiguration(
    DataTypes.EModeCategory storage category
  )
    internal
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    uint256 eModeAssetPrice = 0;

    return (
      category.ltv,
      category.liquidationThreshold,
      eModeAssetPrice
    );
  }

  /**
   * @notice Checks if eMode is active for a user and if yes, if the asset belongs to the eMode category chosen
   * @param eModeUserCategory The user eMode category
   * @param eModeAssetCategory The asset eMode category
   * @return True if eMode is active and the asset belongs to the eMode category chosen by the user, false otherwise
   **/
  function isInEModeCategory(
    uint256 eModeUserCategory,
    uint256 eModeAssetCategory
  ) internal pure returns (bool) {
    return (eModeUserCategory != 0 &&
      eModeAssetCategory == eModeUserCategory);
  }
}
