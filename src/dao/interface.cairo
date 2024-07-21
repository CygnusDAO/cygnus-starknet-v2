use cygnus::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::types::shuttle::{ShuttleDAOReserves};
// DAO Reserves

/// # Title
/// * `CygnusDAOReserves`
///
/// # Description
/// * Where all DAO reserves go from the borrowable and collateral contracts
///
/// # Author
/// * CygnusDAO
use starknet::ContractAddress;

/// # Interface
/// * `IDAOReserves`
#[starknet::interface]
pub trait ICygnusDAOReserves<T> {
    /// -------------------------------------------------------------------------------------------------------
    ///                                        CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// # Returns the name of the DAO reserves contract
    fn name(self: @T) -> felt252;

    /// # Returns the version of the DAO reserves contract
    fn version(self: @T) -> felt252;

    /// # Returns the cold address that holds DAO reserves in LPs and USDC according to the `dao_weight`
    fn cygnus_dao_safe(self: @T) -> ContractAddress;

    /// # Returns the CygnusX1 Vault address that sends this contract's LP and USDC reserves according to `x1_vault_weight`
    fn cygnus_x1_vault(self: @T) -> ContractAddress;

    /// # Returns the weight of reserves that gets sent to `cygnus_dao_safe`
    fn dao_weight(self: @T) -> u256;

    /// # Returns the weight of reserves that gets sent to `cygnus_x1_vault`
    fn x1_vault_weight(self: @T) -> u256;

    /// # Returns the address of the CYG token on Starknet
    fn cyg_token(self: @T) -> ContractAddress;

    /// # Returns the timestamp when CYG tokens get unlocked that get sent here
    fn dao_lock(self: @T) -> u64;

    /// # Returns the Address of USDC on Starknet
    fn usd(self: @T) -> ContractAddress;

    /// Address of the hangar18 factory on Starknet
    fn hangar18(self: @T) -> ContractAddress;

    /// Whether private banker is enabled or not
    fn private_banker(self: @T) -> bool;

    /// Mapping of shuttle_id => ShuttleDAOReserves struct
    fn all_shuttles(self: @T, shuttle_id: u32) -> ShuttleDAOReserves;

    /// # Returns the total shuttles stored in the DAO reserves contract
    fn all_shuttles_length(self: @T) -> u32;

    /// Quick view of our token balance of CYG
    fn cyg_token_balance(self: @T) -> u256;

    /// # Returns the pending x1 vault usd reserves
    fn pending_x1_vault_usd(self: @T) -> u256;

    /// -------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// Redeems the USDC reserves accrued for `shuttle_id` and funds the X1 vault with USDC and funds the dao safe 
    /// with CygUSD according to the current x1_vault_weight
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The amount of USDC sent to the vault
    /// * The amount of CygUSD sent to the safe
    fn fund_x1_vault_usd(ref self: T, shuttle_id: u32) -> (u256, u256);

    /// # Redeems all reserves accrued across all lending pools and funds the x1 vault and dao safe
    ///
    /// # Returns
    /// * The amount of USDC sent to the vault
    /// * The amount of CygUSD sent to the safe
    fn fund_x1_vault_usd_all(ref self: T) -> (u256, u256);

    /// Sends the CygLP received for `shuttle_id` from the liquidation fees to the dao safe
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The amount of CygLP sent to the safe
    fn fund_safe_cyg_lp(ref self: T, shuttle_id: u32) -> u256;

    /// Sends all CygLP received from the liquidation fees to the dao safe
    ///
    /// # Returns
    /// * The amount of CygLP sent to the safe
    fn fund_safe_cyg_lp_all(ref self: T) -> u256;

    /// Adds shuttle to DAO reserves
    ///
    /// # Security
    /// * Only-Factory
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    /// * `borrowable` - The address of the borrowable contract for this lending pool
    /// * `collateral` - The address of the collateral contract for this lending pool
    fn add_shuttle(ref self: T, shuttle_id: u32, borrowable: IBorrowableDispatcher, collateral: ICollateralDispatcher);

    // Admin only //

    /// Admin sets a new weight for the x1 vault from all reserves
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_weight` - The new weight that is sent to the X1 vault from all collected reserves
    fn set_x1_vault_weight(ref self: T, new_weight: u256);

    /// Admin sweeps a token that was sent here by mistake (cant sweep CYG). Uses `amount` to aovid the whole
    /// balance_of/balanceOf and just use `transfer`
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments 
    /// * `token` - The address of the token
    /// * `amount` - The amount to sweep
    fn sweep_token(ref self: T, token: ContractAddress, amount: u256);

    /// Admin claims the CYG token
    ///
    /// # Security
    /// * Only-admin
    /// 
    /// # Arguments
    /// * `amount` - The amount of CYG to recover
    /// * `to` - The address to send the CYG to
    fn claim_cyg_token_dao(ref self: T, amount: u256, to: ContractAddress);

    /// Admin switches on/off the private banker feature, allowing anyone to fund the x1 vault
    ///
    /// # Security
    /// * Only-admin
    fn switch_private_banker(ref self: T);

    /// Admin sets the CYG token
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `cyg_token` - The address of the CYG token on Starknet
    fn set_cyg_token(ref self: T, cyg_token: ContractAddress);


    /// Set the safe to receive CygLP and CygUSD, never redeem assets unless emergency
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments 
    /// * `new_safe` - The address of the new safe
    fn set_cygnus_dao_safe(ref self: T, new_safe: ContractAddress);

    /// Admin sets a new X1 Vault
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments 
    /// * `new_vault` - The address of the x1 vault
    fn set_cygnus_x1_vault(ref self: T, new_vault: ContractAddress);
}

