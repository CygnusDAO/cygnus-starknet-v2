/// Deployers
use cygnus::core::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::core::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};

/// Struct of borrowable & collateral deployers stored in factory
///
/// # Arguments
/// * `status` - Whether the deployers are usable or not (admin can switch off)
/// * `orbiter_id` - Unique ID for the orbiters
/// * `albireo_orbiter` - Address of the borrowable deployer
/// * `deneb_orbiter` - Address of the collateral deployer
/// * `name` - Human friendly name to identify deployers (ie. "Jediswap Pools", "Ekubo Pools", etc.)
#[derive(Drop, starknet::Store, Serde, Copy)]
pub struct Orbiter {
    pub status: bool,
    pub orbiter_id: u32,
    pub albireo_orbiter: IAlbireoDispatcher,
    pub deneb_orbiter: IDenebDispatcher,
    pub name: felt252
}
