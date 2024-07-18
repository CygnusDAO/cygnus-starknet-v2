use cygnus::types::interest::{InterestRateModel, BorrowSnapshot};
/// # Title
/// * `CygnusBorrow`
///
/// # Description
/// * Smart contracts for stablecoin holders to lend their stablecoins to liquidity providers
///
/// # Author
/// * CygnusDAO
use starknet::ContractAddress;
/// use cygnus::rewarder::pillars::{IPillarsOfCreationDispatcher, IPillarsOfCreationDispatcherTrait};

/// # Interface
/// * `IBorrowable`
#[starknet::interface]
pub trait IBorrowable<T> {
    /// --------------------------------------------------------------------------------------------------------
    ///                                          1. ERC20
    /// --------------------------------------------------------------------------------------------------------

    /// Open zeppeplin's implementation of erc20 with u128
    /// https://github.com/OpenZeppelin/cairo-contracts/blob/main/src/token/erc20/erc20.cairo
    ///
    /// commit-hash: 841a073

    /// Returns the name of the token.
    fn name(self: @T) -> felt252;

    /// Returns the ticker symbol of the token, usually a shorter version of the name.
    fn symbol(self: @T) -> felt252;

    /// Returns the number of decimals used to get its user representation.
    fn decimals(self: @T) -> u8;

    /// Returns the amount of tokens owned by `account`.
    fn balance_of(self: @T, account: ContractAddress) -> u128;
    fn balanceOf(self: @T, account: ContractAddress) -> u128;

    /// Returns the value of tokens in existence.
    fn total_supply(self: @T) -> u128;
    fn totalSupply(self: @T) -> u128;

    /// Returns the remaining number of tokens that `spender` is allowed to spend on behalf of `owner` 
    /// through `transfer_from`.
    /// This is zero by default. This value changes when `approve` or `transfer_from` are called.
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u128;

    /// Sets `amount` as the allowance of `spender` over the caller’s tokens.
    fn approve(ref self: T, spender: ContractAddress, amount: u128) -> bool;

    /// Moves `amount` tokens from the caller's token balance to `to`.
    /// Emits a `Transfer` event.
    fn transfer(ref self: T, recipient: ContractAddress, amount: u128) -> bool;

    /// Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    /// Emits a `Transfer` event.
    fn transfer_from(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u128) -> bool;
    fn transferFrom(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u128) -> bool;

    /// Increases the allowance granted from the caller to `spender` by `added_value`.
    /// Emits an `Approval` event indicating the updated allowance.
    fn increase_allowance(ref self: T, spender: ContractAddress, added_value: u128) -> bool;
    fn increaseAllowance(ref self: T, spender: ContractAddress, added_value: u128) -> bool;

    /// Decreases the allowance granted from the caller to `spender` by `subtracted_value`.
    /// Emits an `Approval` event indicating the updated allowance.
    fn decrease_allowance(ref self: T, spender: ContractAddress, subtracted_value: u128) -> bool;
    fn decreaseAllowance(ref self: T, spender: ContractAddress, subtracted_value: u128) -> bool;

    /// --------------------------------------------------------------------------------------------------------
    ///                                          2. TERMINAL
    /// --------------------------------------------------------------------------------------------------------

    /// The factory which deploys pools and has all the important addresses on Starknet
    ///
    /// # Returns
    /// * The address of the factory contract
    fn hangar18(self: @T) -> ContractAddress;

    /// The underlying Stablecoin for this pool
    ///
    /// # Returns
    /// * The address of the stablecoin (USDC, DAI, etc.)
    fn underlying(self: @T) -> ContractAddress;

    /// Each borrowable only has 1 collateral
    ///
    /// # Returns
    /// * The address of the borrowable contract
    fn collateral(self: @T) -> ContractAddress;

    /// The oracle for the underlying LP
    ///
    /// # Returns
    /// * The address of the oracle that prices the LP token
    fn nebula(self: @T) -> ContractAddress;

    /// Unique lending pool ID, shared by the collateral arm
    ///
    /// # Returns
    /// * The lending pool ID
    fn shuttle_id(self: @T) -> u32;

    /// # Returns the total balance of the underlying deposited in the strategy
    fn total_balance(self: @T) -> u128;

    /// Returns the total USD assets held by the vault including assets currently being borrowed.
    /// (ie total_borrows + total_balance)
    fn total_assets(self: @T) -> u128;

    /// Returns the exchange rate between 1 unit of CygLP shares to assets. IE. How much USD
    /// can be redeemed by redeeming 1 unit of CygUSD shares, it should never be below 1e18.
    fn exchange_rate(self: @T) -> u128;

    /// Deposits underlying assets in the pool
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `assets` - The amount of assets to deposit
    /// * `recipient` - The address of the CygUSD recipient
    ///
    /// # Returns
    /// * The amount of shares minted
    fn deposit(ref self: T, assets: u128, recipient: ContractAddress) -> u128;


    /// Redeems CygUSD for USDC Tokens
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `shares` - The amount of shares to redeem
    /// * `recipient` - The address of the recipient of the assets
    /// * `owner` - The address of the owner of the shares
    ///
    /// # Returns
    /// * The amount of assets withdrawn
    fn redeem(ref self: T, shares: u128, recipient: ContractAddress, owner: ContractAddress) -> u128;

    /// Force sync our balance with the total deposited in the strategy
    ///
    /// # Security
    /// * Non-reentrant
    fn sync(ref self: T);

    /// --------------------------------------------------------------------------------------------------------
    ///                                          3. CONTROL 👽
    /// --------------------------------------------------------------------------------------------------------

    /// # Returns the maximum base rate allowed
    fn BASE_RATE_MAX(self: @T) -> u128;

    /// # Returns the maximum reserve factor allowed
    fn RESERVE_FACTOR_MAX(self: @T) -> u128;

    /// # Returns the minimum util rate allowed
    fn KINK_UTIL_MIN(self: @T) -> u128;

    /// # Returns the maximum util rate allowed
    fn KINK_UTIL_MAX(self: @T) -> u128;

    /// # Returns the maximum ink multiplier allowed
    fn KINK_MULTIPLIER_MAX(self: @T) -> u128;

    /// # Return Seconds per year not taking into account leap years
    fn SECONDS_PER_YEAR(self: @T) -> u128;

    /// The current reserve factor, which gets minted to the DAO Reserves (if > 0)
    ///
    /// # Returns
    /// The percentage of reserves the protocol keeps from borrows
    fn reserve_factor(self: @T) -> u128;

    /// We store the interest rate model as a struct which has the base, slope and kink
    ///
    /// # Returns
    /// The interest rate model struct
    fn interest_rate_model(self: @T) -> InterestRateModel;

    /// The CYG rewarder contract, can be 0
    ///
    /// # Returns
    /// * The owner contract of the CYG token allowed to mint
    fn pillars_of_creation(self: @T) -> ContractAddress;

    /// Setter for the reserve factor, can be 0
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_reserve_factor` - The new reserve factor percentage
    fn set_reserve_factor(ref self: T, new_reserve_factor: u128);

    /// Setter for the interest rate model for this pool for this pool for this pool for this pool
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `base_rate` - The new annualized base rate
    /// * `multiplier` - The new annualized slope
    /// * `kink_muliplier` - The kink multiplier when the util reaches the kink
    /// * `kink` - The point at which util increases steeply
    fn set_interest_rate_model(ref self: T, base_rate: u128, multiplier: u128, kink_muliplier: u128, kink: u128);

    /// Setter for the pillars of creation contract, allowed to be 0
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_pillars` - The new CYG rewarder
    fn set_pillars_of_creation(ref self: T, new_pillars: ContractAddress); // TODO

    /// --------------------------------------------------------------------------------------------------------
    ///                                          4. MODEL
    /// --------------------------------------------------------------------------------------------------------

    /// Uses borrow indices
    /// Returns the latest total borrows (with interest accrued)
    fn total_borrows(self: @T) -> u128;

    /// Uses borrow indices
    /// Returns the latest borrow index (with interest accrued)
    fn borrow_index(self: @T) -> u128;

    /// Uses borrow indices
    /// Returns the timestamp of the last accrual
    fn last_accrual_timestamp(self: @T) -> u64;

    /// Uses borrow indices
    /// # Returns
    /// * The current utilization rate
    fn utilization_rate(self: @T) -> u128;

    /// Uses borrow indices
    /// # Returns
    /// * The latest borrow rate per second (note: not annualized)
    fn borrow_rate(self: @T) -> u128;

    /// Uses borrow indices
    /// # Returns
    /// * The current supply rate for lenders, without taking into account strategy/rewards
    fn supply_rate(self: @T) -> u128;

    /// Uses borrow indices
    /// Reads from the BorrowSnapshot struct and uses the borrow indices to calculate
    /// the current borrows in real time
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The borrower's principal (ie the borrowed amount without interest rate)
    /// * The borrower's borrow balance (principal with interests)
    fn get_borrow_balance(self: @T, borrower: ContractAddress) -> (u128, u128);

    /// # Returns
    /// * The price of the stablecoin in USD
    fn get_usd_price(self: @T) -> u128;

    /// # Returns
    /// * The lender's CygUSD balance
    /// * The lender's USDC balance
    /// * The lender's position in USD (uses pragma to price USDC)
    fn get_lender_position(self: @T, lender: ContractAddress) -> (u128, u128, u128);

    /// Accrues interest for all borrowers, increasing `total_borrows` and storing the latest `borrow_rate`
    fn accrue_interest(ref self: T);

    /// Tracks the borrower's principal in the rewarder
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    fn track_borrower(ref self: T, borrower: ContractAddress);

    /// Tracks the lenders CygUSD balance in the rewarder
    ///
    /// # Arguments
    /// * `lender` - The address of the lender
    fn track_lender(ref self: T, lender: ContractAddress);

    /// Total position IDs
    fn all_positions_length(self: @T) -> u32;

    /// Get address of position ID
    fn all_positions(self: @T, position_id: u32) -> ContractAddress;

    /// --------------------------------------------------------------------------------------------------------
    ///                                          5. BORROWABLE
    /// --------------------------------------------------------------------------------------------------------

    /// Main function to borrow funds from the pool
    /// This function should be called from a periphery contract only
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower (pricing their collateral)
    /// * `receiver` - The address of the receiver of the borrowed funds
    /// * `borrow_amount` - The amount of stablecoins to borrow
    /// * `calldata` - Calldata passed for leverage/flash loans
    fn borrow(
        ref self: T, borrower: ContractAddress, receiver: ContractAddress, borrow_amount: u128, calldata: Array<felt252>
    ) -> u128;

    /// Main function to liquidate or flash liquidate a borrower.
    /// This function should be called from a periphery contract only
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower being liquidated
    /// * `receiver` - The address of the receiver of the liquidation bonus
    /// * `repay_amount` - The USD amount being repaid
    /// * `calldata` - Calldata passed for flash liquidating
    fn liquidate(
        ref self: T, borrower: ContractAddress, receiver: ContractAddress, repay_amount: u128, calldata: Array<felt252>
    ) -> u128;
}
