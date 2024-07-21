use cygnus::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
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
    ///                                          1. ERC20
    ///--------------------------------------------------------------------------------------------------------

    /// Open zeppeplin's implementation of erc20 with u256
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
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn balanceOf(self: @T, account: ContractAddress) -> u256;

    /// Returns the value of tokens in existence.
    fn total_supply(self: @T) -> u256;
    fn totalSupply(self: @T) -> u256;

    /// Returns the remaining number of tokens that `spender` is allowed to spend on behalf of `owner` 
    /// through `transfer_from`.
    /// This is zero by default. This value changes when `approve` or `transfer_from` are called.
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Sets `amount` as the allowance of `spender` over the caller’s tokens.
    fn approve(ref self: T, spender: ContractAddress, amount: u256) -> bool;

    /// Moves `amount` tokens from the caller's token balance to `to`.
    /// Emits a `Transfer` event.
    fn transfer(ref self: T, recipient: ContractAddress, amount: u256) -> bool;

    /// Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    /// Emits a `Transfer` event.
    fn transfer_from(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(ref self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;

    /// Increases the allowance granted from the caller to `spender` by `added_value`.
    /// Emits an `Approval` event indicating the updated allowance.
    fn increase_allowance(ref self: T, spender: ContractAddress, added_value: u256) -> bool;
    fn increaseAllowance(ref self: T, spender: ContractAddress, added_value: u256) -> bool;

    /// Decreases the allowance granted from the caller to `spender` by `subtracted_value`.
    /// Emits an `Approval` event indicating the updated allowance.
    fn decrease_allowance(ref self: T, spender: ContractAddress, subtracted_value: u256) -> bool;
    fn decreaseAllowance(ref self: T, spender: ContractAddress, subtracted_value: u256) -> bool;

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
    fn total_balance(self: @T) -> u256;

    /// Returns the total LP assets held by the vault (ie. total_balance)
    fn total_assets(self: @T) -> u256;

    /// Returns the exchange rate between 1 unit of CygLP shares to assets. IE. How much LP
    /// can be redeemed by redeeming 1 unit of CygLP shares. It should never be below 1e18.
    fn exchange_rate(self: @T) -> u256;

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
    fn deposit(ref self: T, assets: u256, recipient: ContractAddress) -> u256;


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
    fn redeem(ref self: T, shares: u256, recipient: ContractAddress, owner: ContractAddress) -> u256;

    /// Force sync our balance with the total deposited in the strategy
    ///
    /// # Security
    /// * Non-reentrant
    fn sync(ref self: T);

    ///--------------------------------------------------------------------------------------------------------
    ///                                          3. CONTROL
    ///--------------------------------------------------------------------------------------------------------

    /// # Returns the minimum debt ratio allowed
    fn DEBT_RATIO_MIN(self: @T) -> u256;

    /// # Returns the maximum debt ratio allowed
    fn DEBT_RATIO_MAX(self: @T) -> u256;

    /// # Returns the maximum liquidation incentive allowed
    fn LIQUIDATION_INCENTIVE_MAX(self: @T) -> u256;

    /// # Returns the minimum liquidation incentive allowed
    fn LIQUIDATION_INCENTIVE_MIN(self: @T) -> u256;

    /// # Returns the maximum liquidation fee allowed
    fn LIQUIDATION_FEE_MAX(self: @T) -> u256;

    /// # Returns the current pool's debt ratio
    fn debt_ratio(self: @T) -> u256;

    /// # Returns the current pool's liquidation fee
    fn liquidation_fee(self: @T) -> u256;

    /// # Returns the current pool's liquidation incentive
    fn liquidation_incentive(self: @T) -> u256;

    /// Sets the borrowable during deployment. Can only be set once (does address zero check).
    ///
    /// # Security
    /// * Can only be set once, reverts if borrowable address is not zero!
    ///
    /// # Arguments
    /// * `borrowable` - The address of the borrowable
    fn set_borrowable(ref self: T, borrowable: IBorrowableDispatcher);

    /// Sets liquidation fee 
    ///
    /// # Security 
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_liq_fee` - The new liquidation fee
    fn set_liquidation_fee(ref self: T, new_liq_fee: u256);

    /// Sets liquidation incentive
    ///
    /// # Security 
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `incentive` - The new liquidation incentive
    fn set_liquidation_incentive(ref self: T, new_incentive: u256);

    /// Sets a new debt ratio
    ///
    /// # Security
    /// * Only-admin 👽
    ///
    /// # Arguments
    /// * `new_ratio` - The new debt ratio
    fn set_debt_ratio(ref self: T, new_ratio: u256);

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
    fn can_borrow(self: @T, borrower: ContractAddress, amount: u256) -> bool;

    /// Checks whether or not a borrower can redeem a certain amount of CygLP
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// * `amount` - The amount of CygLP to redeem
    ///
    /// # Returns
    /// * Whether or not the borrower can withdraw 'amount' of CygLP. If false then it means withdrawing
    ///   this amount of CygLP would put user in shortfall and withdrawing this would cause the tx to revert
    fn can_redeem(self: @T, borrower: ContractAddress, amount: u256) -> bool;

    /// Checks a borrower's current liquidity and shortfall. 
    /// 
    /// # Arguments
    /// * `borrower` - The address of the borrower
    /// 
    /// # Returns
    /// * The maximum amount of USDC that the `borrower` can borrow (if shortfall then this == 0)
    /// * The current shortfall of USDC (if liquidity then this == 0)
    fn get_account_liquidity(self: @T, borrower: ContractAddress) -> (u256, u256);

    /// # Returns
    /// * The price of the underlying LP Token, denominated in the borrowable`s underlying
    fn get_lp_token_price(self: @T) -> u256;

    /// Quick check to see borrower`s position
    ///
    /// # Arguments
    /// * `borrower` - The address of the borrower
    ///
    /// # Returns
    /// * The borrower's position in LPs
    /// * The borrower's position in USD
    /// * The borrower's health (0.5e18 = 50%, liquidatable at 100% ie 1e18)
    fn get_borrower_position(self: @T, borrower: ContractAddress) -> (u256, u256, u256);

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
    fn seize_cyg_lp(ref self: T, liquidator: ContractAddress, borrower: ContractAddress, repay_amount: u256) -> u256;

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
    fn flash_redeem(ref self: T, redeemer: ContractAddress, redeem_amount: u256, calldata: Array<felt252>) -> u256;
}

