// Imports
use starknet::ContractAddress;

/// # Interface
/// * `ICollateral`
#[starknet::interface]
pub trait ITerminal<T> {
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
    fn total_balance(self: @T) -> u128;

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
}
