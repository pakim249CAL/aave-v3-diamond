// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

/**
 * @title Errors library
 * @author Aave
 * @notice Defines the error messages emitted by the different contracts of the Aave protocol
 */
library Errors {
  string internal constant CALLER_NOT_POOL_ADMIN = "1"; // 'The caller of the function is not a pool admin'
  string internal constant CALLER_NOT_EMERGENCY_ADMIN = "2"; // 'The caller of the function is not an emergency admin'
  string internal constant CALLER_NOT_POOL_OR_EMERGENCY_ADMIN = "3"; // 'The caller of the function is not a pool or emergency admin'
  string internal constant CALLER_NOT_RISK_OR_POOL_ADMIN = "4"; // 'The caller of the function is not a risk or pool admin'
  string internal constant CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN =
    "5"; // 'The caller of the function is not an asset listing or pool admin'
  string internal constant CALLER_NOT_BRIDGE = "6"; // 'The caller of the function is not a bridge'
  string internal constant ADDRESSES_PROVIDER_NOT_REGISTERED = "7"; // 'Pool addresses provider is not registered'
  string internal constant INVALID_ADDRESSES_PROVIDER_ID = "8"; // 'Invalid id for the pool addresses provider'
  string internal constant NOT_CONTRACT = "9"; // 'Address is not a contract'
  string internal constant CALLER_NOT_POOL_CONFIGURATOR = "10"; // 'The caller of the function is not the pool configurator'
  string internal constant CALLER_NOT_ATOKEN = "11"; // 'The caller of the function is not an AToken'
  string internal constant INVALID_ADDRESSES_PROVIDER = "12"; // 'The address of the pool addresses provider is invalid'
  string internal constant INVALID_FLASHLOAN_EXECUTOR_RETURN = "13"; // 'Invalid return value of the flashloan executor function'
  string internal constant RESERVE_ALREADY_ADDED = "14"; // 'Reserve has already been added to reserve list'
  string internal constant NO_MORE_RESERVES_ALLOWED = "15"; // 'Maximum amount of reserves in the pool reached'
  string internal constant EMODE_CATEGORY_RESERVED = "16"; // 'Zero eMode category is reserved for volatile heterogeneous assets'
  string internal constant INVALID_EMODE_CATEGORY_ASSIGNMENT = "17"; // 'Invalid eMode category assignment to asset'
  string internal constant RESERVE_LIQUIDITY_NOT_ZERO = "18"; // 'The liquidity of the reserve needs to be 0'
  string internal constant FLASHLOAN_PREMIUM_INVALID = "19"; // 'Invalid flashloan premium'
  string internal constant INVALID_RESERVE_PARAMS = "20"; // 'Invalid risk parameters for the reserve'
  string internal constant INVALID_EMODE_CATEGORY_PARAMS = "21"; // 'Invalid risk parameters for the eMode category'
  string internal constant BRIDGE_PROTOCOL_FEE_INVALID = "22"; // 'Invalid bridge protocol fee'
  string internal constant CALLER_MUST_BE_POOL = "23"; // 'The caller of this function must be a pool'
  string internal constant INVALID_MINT_AMOUNT = "24"; // 'Invalid amount to mint'
  string internal constant INVALID_BURN_AMOUNT = "25"; // 'Invalid amount to burn'
  string internal constant INVALID_AMOUNT = "26"; // 'Amount must be greater than 0'
  string internal constant RESERVE_INACTIVE = "27"; // 'Action requires an active reserve'
  string internal constant RESERVE_FROZEN = "28"; // 'Action cannot be performed because the reserve is frozen'
  string internal constant RESERVE_PAUSED = "29"; // 'Action cannot be performed because the reserve is paused'
  string internal constant BORROWING_NOT_ENABLED = "30"; // 'Borrowing is not enabled'
  string internal constant STABLE_BORROWING_NOT_ENABLED = "31"; // 'Stable borrowing is not enabled'
  string internal constant NOT_ENOUGH_AVAILABLE_USER_BALANCE = "32"; // 'User cannot withdraw more than the available balance'
  string internal constant INVALID_INTEREST_RATE_MODE_SELECTED = "33"; // 'Invalid interest rate mode selected'
  string internal constant COLLATERAL_BALANCE_IS_ZERO = "34"; // 'The collateral balance is 0'
  string
    internal constant HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD =
    "35"; // 'Health factor is lesser than the liquidation threshold'
  string internal constant COLLATERAL_CANNOT_COVER_NEW_BORROW = "36"; // 'There is not enough collateral to cover a new borrow'
  string internal constant COLLATERAL_SAME_AS_BORROWING_CURRENCY =
    "37"; // 'Collateral is (mostly) the same currency that is being borrowed'
  string internal constant AMOUNT_BIGGER_THAN_MAX_LOAN_SIZE_STABLE =
    "38"; // 'The requested amount is greater than the max loan size in stable rate mode'
  string internal constant NO_DEBT_OF_SELECTED_TYPE = "39"; // 'For repayment of a specific type of debt, the user needs to have debt that type'
  string internal constant NO_EXPLICIT_AMOUNT_TO_REPAY_ON_BEHALF =
    "40"; // 'To repay on behalf of a user an explicit amount to repay is needed'
  string internal constant NO_OUTSTANDING_STABLE_DEBT = "41"; // 'User does not have outstanding stable rate debt on this reserve'
  string internal constant NO_OUTSTANDING_VARIABLE_DEBT = "42"; // 'User does not have outstanding variable rate debt on this reserve'
  string internal constant UNDERLYING_BALANCE_ZERO = "43"; // 'The underlying balance needs to be greater than 0'
  string
    internal constant INTEREST_RATE_REBALANCE_CONDITIONS_NOT_MET =
    "44"; // 'Interest rate rebalance conditions were not met'
  string internal constant HEALTH_FACTOR_NOT_BELOW_THRESHOLD = "45"; // 'Health factor is not below the threshold'
  string internal constant COLLATERAL_CANNOT_BE_LIQUIDATED = "46"; // 'The collateral chosen cannot be liquidated'
  string internal constant SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER =
    "47"; // 'User did not borrow the specified currency'
  string internal constant SAME_BLOCK_BORROW_REPAY = "48"; // 'Borrow and repay in same block is not allowed'
  string internal constant INCONSISTENT_FLASHLOAN_PARAMS = "49"; // 'Inconsistent flashloan parameters'
  string internal constant BORROW_CAP_EXCEEDED = "50"; // 'Borrow cap is exceeded'
  string internal constant SUPPLY_CAP_EXCEEDED = "51"; // 'Supply cap is exceeded'
  string internal constant UNBACKED_MINT_CAP_EXCEEDED = "52"; // 'Unbacked mint cap is exceeded'
  string internal constant DEBT_CEILING_EXCEEDED = "53"; // 'Debt ceiling is exceeded'
  string internal constant ATOKEN_SUPPLY_NOT_ZERO = "54"; // 'AToken supply is not zero'
  string internal constant STABLE_DEBT_NOT_ZERO = "55"; // 'Stable debt supply is not zero'
  string internal constant VARIABLE_DEBT_SUPPLY_NOT_ZERO = "56"; // 'Variable debt supply is not zero'
  string internal constant LTV_VALIDATION_FAILED = "57"; // 'Ltv validation failed'
  string internal constant INCONSISTENT_EMODE_CATEGORY = "58"; // 'Inconsistent eMode category'
  string internal constant PRICE_ORACLE_SENTINEL_CHECK_FAILED = "59"; // 'Price oracle sentinel validation failed'
  string internal constant ASSET_NOT_BORROWABLE_IN_ISOLATION = "60"; // 'Asset is not borrowable in isolation mode'
  string internal constant RESERVE_ALREADY_INITIALIZED = "61"; // 'Reserve has already been initialized'
  string internal constant USER_IN_ISOLATION_MODE = "62"; // 'User is in isolation mode'
  string internal constant INVALID_LTV = "63"; // 'Invalid ltv parameter for the reserve'
  string internal constant INVALID_LIQ_THRESHOLD = "64"; // 'Invalid liquidity threshold parameter for the reserve'
  string internal constant INVALID_LIQ_BONUS = "65"; // 'Invalid liquidity bonus parameter for the reserve'
  string internal constant INVALID_DECIMALS = "66"; // 'Invalid decimals parameter of the underlying asset of the reserve'
  string internal constant INVALID_RESERVE_FACTOR = "67"; // 'Invalid reserve factor parameter for the reserve'
  string internal constant INVALID_BORROW_CAP = "68"; // 'Invalid borrow cap for the reserve'
  string internal constant INVALID_SUPPLY_CAP = "69"; // 'Invalid supply cap for the reserve'
  string internal constant INVALID_LIQUIDATION_PROTOCOL_FEE = "70"; // 'Invalid liquidation protocol fee for the reserve'
  string internal constant INVALID_EMODE_CATEGORY = "71"; // 'Invalid eMode category for the reserve'
  string internal constant INVALID_UNBACKED_MINT_CAP = "72"; // 'Invalid unbacked mint cap for the reserve'
  string internal constant INVALID_DEBT_CEILING = "73"; // 'Invalid debt ceiling for the reserve
  string internal constant INVALID_RESERVE_INDEX = "74"; // 'Invalid reserve index'
  string internal constant ACL_ADMIN_CANNOT_BE_ZERO = "75"; // 'ACL admin cannot be set to the zero address'
  string internal constant INCONSISTENT_PARAMS_LENGTH = "76"; // 'Array parameters that should be equal length are not'
  string internal constant ZERO_ADDRESS_NOT_VALID = "77"; // 'Zero address not valid'
  string internal constant INVALID_EXPIRATION = "78"; // 'Invalid expiration'
  string internal constant INVALID_SIGNATURE = "79"; // 'Invalid signature'
  string internal constant OPERATION_NOT_SUPPORTED = "80"; // 'Operation not supported'
  string internal constant DEBT_CEILING_NOT_ZERO = "81"; // 'Debt ceiling is not zero'
  string internal constant ASSET_NOT_LISTED = "82"; // 'Asset is not listed'
  string internal constant INVALID_OPTIMAL_USAGE_RATIO = "83"; // 'Invalid optimal usage ratio'
  string
    internal constant INVALID_OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO =
    "84"; // 'Invalid optimal stable to total debt ratio'
  string internal constant UNDERLYING_CANNOT_BE_RESCUED = "85"; // 'The underlying asset cannot be rescued'
  string internal constant ADDRESSES_PROVIDER_ALREADY_ADDED = "86"; // 'Reserve has already been added to reserve list'
  string internal constant POOL_ADDRESSES_DO_NOT_MATCH = "87"; // 'The token implementation pool address and the pool address provided by the initializing pool do not match'
  string internal constant STABLE_BORROWING_ENABLED = "88"; // 'Stable borrowing is enabled'
  string internal constant SILOED_BORROWING_VIOLATION = "89"; // 'User is trying to borrow multiple assets including a siloed one'
  string internal constant RESERVE_DEBT_NOT_ZERO = "90"; // the total debt of the reserve needs to be 0
}
