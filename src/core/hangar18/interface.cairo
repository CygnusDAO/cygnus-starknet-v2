// Imports.
use cygnus::core::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::core::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::core::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::core::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use cygnus::dao::reserves::{ICygnusDAOReservesDispatcher};
use cygnus::types::ekubo::PoolKeyCYG;
use cygnus::types::orbiter::Orbiter;
use cygnus::types::shuttle::Shuttle;

use starknet::ContractAddress;

/// # Interface - Hangar18
#[starknet::interface]
pub trait IHangar18<T> {
    /// --------------------------------------------------------------------------------------------------------
    ///                                        CONSTANT FUNCTIONS
    /// --------------------------------------------------------------------------------------------------------

    /// # Returns the name of the factory (`Hangar18`)
    fn name(self: @T) -> ByteArray;

    /// # Returns the version of the hangar18 deployed (to be compatible with other chains)
    fn version(self: @T) -> ByteArray;

    /// # Returns the address of the current admin, the pool/orbiter deployer
    fn admin(self: @T) -> ContractAddress;

    /// # Returns the address of the current pending admin
    fn pending_admin(self: @T) -> ContractAddress;

    /// # Returns the address of the oracle registry
    fn nebula_registry(self: @T) -> ContractAddress;

    /// # Returns the address of the DAO reserves
    fn dao_reserves(self: @T) -> ContractAddress;

    /// # Returns the address of the borrow token for all Cygnus pools
    fn usd(self: @T) -> ContractAddress;

    /// # Returns the address of the native token on starknet (ie ETH)
    fn native_token(self: @T) -> ContractAddress;

    /// # Returns the address of the X1 vault on Starknet
    fn cygnus_x1_vault(self: @T) -> ContractAddress;

    /// # Returns the address of the pillars of creation contract on Starknet
    fn cygnus_pillars(self: @T) -> ContractAddress;

    /// # Returns the address of the current router used by our frontend
    fn cygnus_altair(self: @T) -> ContractAddress;

    /// # Returns the orbiter struct given an orbiter ID
    fn all_orbiters(self: @T, id: u32) -> Orbiter;

    /// # Returns the shuttle struct given a shuttle ID
    fn all_shuttles(self: @T, id: u32) -> Shuttle;

    /// # Returns the total number of orbiters deployed
    fn orbiters_deployed(self: @T) -> u32;

    /// # Returns the total number of shuttles deployed
    fn shuttles_deployed(self: @T) -> u32;

    /// Quick reporting functions on this chain to get TVLs in USD. Uses 6 decimals since our
    /// lending token is USDC.

    /// # Returns the chain ID of the hangar18
    fn chain_id(self: @T) -> felt252;

    /// Gets a lending pool tvl (usdc deposits + lp deposits) priced in USD
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The TVL of the shuttle
    fn shuttle_tvl_usd(self: @T, shuttle_id: u32) -> u128;

    /// Gets a collateral tvl (LP deposits) priced in USD
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The TVL of the collateral
    fn collateral_tvl_usd(self: @T, shuttle_id: u32) -> u128;

    /// Gets a borrowable tvl (USDC deposits + borrows) priced in USD
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the lending pool
    ///
    /// # Returns
    /// * The TVL of the borrowable
    fn borrowable_tvl_usd(self: @T, shuttle_id: u32) -> u128;

    /// # Returns
    /// * Cygnus protocol current total borrows
    fn cygnus_total_borrows_usd(self: @T) -> u128;

    /// # Returns
    /// * The tvl of all collaterals 
    fn all_collaterals_tvl(self: @T) -> u128;

    /// # Returns
    /// * The tvl of all borrowbales
    fn all_borrowables_tvl(self: @T) -> u128;

    /// # Returns
    /// * The tvl of the whole protocol on Starknet
    fn cygnus_tvl_usd(self: @T) -> u128;

    /// --------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    /// --------------------------------------------------------------------------------------------------------

    /// Sets a new orbiter in the factory
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `name` - Human friendly name for the orbiter (ie. `JediSwap Orbiter`)
    /// * `albireo` - The address of the borrowable deployer
    /// * `deneb` - The address of the collateral deployer
    fn set_orbiter(ref self: T, name: felt252, albireo_orbiter: IAlbireoDispatcher, deneb_orbiter: IDenebDispatcher);

    /// Deploys a new lending pool
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `orbiter_id` - The unique id for the deployers
    /// * `lp_token_pair` - The address of the LP Token
    ///
    /// # Returns
    /// * Borrowable and collateral contracts deployed
    fn deploy_shuttle(
        ref self: T, orbiter_id: u32, pool_key: PoolKeyCYG
    ) -> (IBorrowableDispatcher, ICollateralDispatcher);

    /// Sets a new pending admin for the factory. This admin controls the most important
    /// variables across the whole protcol on this chain.
    ///
    /// # Security
    /// * Only-admin
    ///
    /// # Arguments
    /// * `new_pending_admin` - The address of the new pending admin
    fn set_pending_admin(ref self: T, new_pending_admin: ContractAddress);

    /// Pending admin accepts the admin role
    ///
    /// # Security
    /// * Only-pending-admin
    fn accept_admin(ref self: T);

    /// Switches orbiter status, reverting future deployments with this orbiter unless turned on again
    ///
    /// # Security
    /// * Only-admin
    fn switch_orbiter_status(ref self: T, orbiter_id: u32);

    /// Sets the periphery contract that is currently used by Cygnus frontend
    ///
    /// # Security
    /// * Only-admin
    fn set_cygnus_altair(ref self: T, new_cygnus_altair: ContractAddress);

    /// Sets the X1 vault on Starknet
    ///
    /// # Security
    /// * Only-admin
    fn set_cygnus_x1_vault(ref self: T, new_cygnus_x1_vault: ContractAddress);

    /// Sets the CYG rewarder on Starknet
    ///
    /// # Security
    /// * Only-admin
    fn set_cygnus_pillars(ref self: T, new_cygnus_pillars: ContractAddress);
}

