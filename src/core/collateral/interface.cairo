use cygnus::core::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::types::terminal::{DepositParams, RedeemParams};
use ekubo::types::keys::PoolKey;

/// # Title
/// * `CygnusCollateral`
///
/// # Description
/// * Smart contract for liquidity providers to deposit their liquidity and use it as collateral to borrow stbalecoins
///
/// # Author
/// * CygnusDAO
use starknet::ContractAddress;

/// # Interface
/// * `ICollateral`
#[starknet::interface]
pub trait ICollateral<T> {
    ///--------------------------------------------------------------------------------------------------------
    ///                                          2. TERMINAL
    ///--------------------------------------------------------------------------------------------------------

    /// The factory which deploys pools and has all the important addresses on Starknet
    ///
    /// # Returns
    /// * The address of the factory contract
    fn hangar18(self: @T) -> ContractAddress;

    /// The underlying LP Token for this pool
    ///
    /// # Returns
    /// * The address of the underlying LP
    fn underlying(self: @T) -> ContractAddress;

    /// The Ekubo pool key
    fn pool_key(self: @T) -> PoolKey;

    /// Each collateral only has 1 borrowable which may borrow funds from
    ///
    /// # Returns
    /// * The address of the borrowable contract
    fn borrowable(self: @T) -> ContractAddress;

    /// The oracle for the underlying LP
    ///
    /// # Returns
    /// * The address of the oracle that prices the LP token
    fn nebula(self: @T) -> ContractAddress;

    /// Unique lending pool ID, shared by the borrowable arm
    ///
    /// # Returns
    /// * The lending pool ID
    fn shuttle_id(self: @T) -> u32;

    /// # Returns the total balance of the underlying deposited in the strategy
    fn total_balance(self: @T, id: u64) -> u128;

    /// Returns the total LP assets held by the vault (ie. total_balance)
    fn total_assets(self: @T) -> u128;

    /// Returns the exchange rate between 1 unit of CygLP shares to assets. IE. How much LP
    /// can be redeemed by redeeming 1 unit of CygLP shares. It should never be below 1e18.
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
    fn deposit(ref self: T, params: DepositParams) -> u128;

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
    fn redeem(ref self: T, params: RedeemParams) -> (u128, u128);

    /// Force sync our balance with the total deposited in the strategy
    ///
    /// # Security
    /// * Non-reentrant
    fn sync(ref self: T, token_id: u64);

    // On received
    fn on_erc721_received(
        self: @T, operator: ContractAddress, from: ContractAddress, token_id: u128, data: Span<felt252>
    ) -> felt252;

    ///--------------------------------------------------------------------------------------------------------
    ///                                          3. CONTROL
    ///--------------------------------------------------------------------------------------------------------

    /// # Returns the current pool's debt ratio
    fn debt_ratio(self: @T) -> u128;

    /// # Returns the current pool's liquidation fee
    fn liquidation_fee(self: @T) -> u128;

    /// # Returns the current pool's liquidation incentive
    fn liquidation_incentive(self: @T) -> u128;

    /// Sets the borrowable during deployment. Can only be set once (does address zero check).
    ///
    /// # Security
    /// * Can only be set once, reverts if borrowable address is not zero!
    ///
    /// # Arguments
    /// * `borrowable` - The address of the borrowable
    fn set_borrowable(ref self: T, borrowable: IBorrowableDispatcher);

    ///--------------------------------------------------------------------------------------------------------
    ///                                          4. MODEL
    ///--------------------------------------------------------------------------------------------------------

    /// Checks whether a borrower can borrow a certain amount, used by the borrowable contract
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// * `amount` - The amount to borrow
    ///
    /// # Returns 
    /// * Whether or not `borrower` can borrow `amount`
    fn can_borrow(self: @T, borrower: ContractAddress, amount: u128) -> bool;

    /// Checks whether or not a borrower can redeem a certain amount of CygLP
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// * `amount` - The amount of CygLP to redeem
    ///
    /// # Returns
    /// * Whether or not the borrower can withdraw 'amount' of CygLP. If false then it means withdrawing
    ///   this amount of CygLP would put user in shortfall and withdrawing this would cause the tx to revert
    fn can_redeem(self: @T, borrower: ContractAddress, amount: u128) -> bool;

    /// Checks a borrower's current liquidity and shortfall. 
    /// 
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// 
    /// # Returns
    /// * The maximum amount of USDC that the `borrower` can borrow (if shortfall then this == 0)
    /// * The current shortfall of USDC (if liquidity then this == 0)
    fn get_account_liquidity(self: @T, borrower: ContractAddress) -> (u128, u128);

    /// # Returns
    /// * The price of the underlying LP Token, denominated in the borrowable`s underlying
    fn get_lp_token_price(self: @T) -> u128;

    /// Quick check to see borrower`s position
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The borrower's position in LPs
    /// * The borrower's position in USD
    /// * The borrower's health (0.5e18 = 50%, liquidatable at 100% ie 1e18)
    fn get_borrower_position(self: @T, borrower: ContractAddress) -> (u128, u128, u128);

    ///--------------------------------------------------------------------------------------------------------
    ///                                          5. COLLATERAL
    ///--------------------------------------------------------------------------------------------------------

    /// Seizes an amount of CygLP from the borrower and transfers it to the liquidator.
    /// Not marked as non-reentrant as only borrowable can call through the non-reentrant `liquidate`
    ///
    /// # Security
    /// * Non-reentrant
    /// * Only-borrowable
    ///
    /// # Arguments
    /// * `liquidator` - The address of the liquidator
    /// * `borrower` - The address of the borrower
    /// * `repay_amount` - The amount of USDC repaid by the liquidator
    ///
    /// # Returns
    /// * The amount of CygLP seized
    fn seize_cyg_lp(ref self: T, liquidator: ContractAddress, borrower: ContractAddress, repay_amount: u128) -> u128;

    /// Flash redeems LP from the vault and sends it to `redeemer`, expecting an equivalent amount of CygLP to be received
    /// by the end of the function.
    ///
    /// # Security
    /// * Non-reentrant
    ///
    /// # Arguments
    /// * `redeemer` - The recipient of the LP tokens
    /// * `redeem_amount,` - The amount of LP to flash redeem
    /// * `calldata` - Calldata passed to the router
    ///
    /// # Returns
    /// * The amount of USDC received (if any)
    fn flash_redeem(ref self: T, redeemer: ContractAddress, redeem_amount: u128, calldata: Array<felt252>) -> u128;
}

