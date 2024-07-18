use cygnus::types::nebula::LPInfo;
use cygnus::types::nebula_registry::Nebula;
use starknet::ContractAddress;
//use array::ArrayTrait;

/// Interface - Oracle Registry
#[starknet::interface]
pub trait INebulaRegistry<T> {
    /// -------------------------------------------------------------------------------------------------------
    ///                                        CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * The address of the registry admin, only one that can initialize oracles
    fn admin(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the pending admin (can be zero)
    fn pending_admin(self: @T) -> ContractAddress;

    /// # Returns
    /// * The total amounts of oracle logics (nebulas) we have
    fn all_nebulas_length(self: @T) -> u32;

    /// # Returns
    /// * The total amount of LPs we are tracking
    fn all_lp_tokens_length(self: @T) -> u32;

    /// IMPORTANT: Do not use this price as it does no safety checks if the aggregators fail.
    ///            This is only kept here for reporting purposes.
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP token
    ///
    /// # Returns
    /// * The price of the lp token (gets the nebula for the LP, and calls `lp_token_price_usd`)
    fn get_lp_token_price_usd(self: @T, lp_token_pair: ContractAddress) -> u128;

    /// # Arguments
    /// * `nebula_address` - The address of the nebula implementation
    ///
    /// # Returns
    /// * The nebula struct given the nebula address
    fn get_nebula(self: @T, nebula_address: ContractAddress) -> Nebula;

    /// # Arguments
    /// * `lp_token_pair` - The address of the LP token
    ///
    /// # Returns
    /// * The nebula struct given an LP token pair (if we are tracking it)
    fn get_lp_token_nebula(self: @T, lp_token_pair: ContractAddress) -> Nebula;

    /// This is used by the factory to deploy pools as it's more gas efficient
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP token
    ///
    /// # Returns
    /// * The nebula address given an LP Token pair
    fn get_lp_token_nebula_address(self: @T, lp_token_pair: ContractAddress) -> ContractAddress;

    /// Gets a quick overview of the LP Token
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP Token
    ///
    /// # Returns
    /// * Array of all token addresses that compose the LP
    /// * Array of the reserves of each token in the LP
    /// * Array of decimals of each token in the LP
    /// * Array of prices of each token in the LP
    fn get_lp_token_info(self: @T, lp_token_pair: ContractAddress) -> LPInfo;

    /// Array of nebulas
    ///
    /// # Arguments
    /// * `nebula_id` - The unique ID of a nebula
    ///
    /// # Returns
    /// * The Nebula struct for this `nebula_id`
    fn all_nebulas(self: @T, nebula_id: u32) -> Nebula;

    /// -------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// Stores a new nebula logic in this registry and assigns it a unique ID.
    /// The nebula logic is basically an oracle that prices specific lp tokens such as 
    /// Balancer's BPT Weighted Pools or UniswapV2 pools.
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `nebula_address` - The address of the new nebula
    fn create_nebula(ref self: T, nebula_address: ContractAddress);

    /// Adds an LP oracle to a nebula in the registry. Only the registry can initialize
    /// Nebulas and Oracles. If an oracle for an LP is not set, then pools cannot be deployed
    /// as collaterals cannot be priced.
    ///
    /// # Security
    /// * Only-admin
    /// 
    /// # Arguments
    /// * `nebula_id` - The unique ID of the nebula where we are initializing the oracle
    /// * `lp_token_pair` - The address of the LP Token
    /// * `price_feeds` - Array of price feeds for each token in the LP
    /// * `is_override` - Whether we are overriding an already existing LP oracle for future pools.
    fn create_nebula_oracle(
        ref self: T,
        nebula_id: u32,
        lp_token_pair: ContractAddress,
        price_feed0: felt252,
        price_feed1: felt252,
        is_override: bool
    );

    /// Sets a new pending admin, for them to accept and transfer ownership of this registry
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_pending` - The address of the new pending admin
    fn set_pending_admin(ref self: T, new_pending: ContractAddress);

    /// Pending admin accepts ownership of the registry
    ///
    /// # Security
    /// * Only-pending-admin
    fn accept_admin(ref self: T);
}

