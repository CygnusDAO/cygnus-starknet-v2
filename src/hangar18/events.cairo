// Hangar18 Events

// Imports
use cygnus::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
use cygnus::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use starknet::ContractAddress;

/// @custom:event NewAdmin Emitted when a new factory admin is set
#[derive(Drop, starknet::Event)]
pub struct NewAdmin {
    pub old_admin: ContractAddress,
    pub new_admin: ContractAddress
}

/// @custom:event NewPendingAdmin Emitted when a new factory pending admin is set
#[derive(Drop, starknet::Event)]
pub struct NewPendingAdmin {
    pub old_pending_admin: ContractAddress,
    pub new_pending_admin: ContractAddress
}

/// @custom:event NewOrbiter Emitted when a new orbiter is set
#[derive(Drop, starknet::Event)]
pub struct NewOrbiter {
    pub orbiter_id: u32,
    pub albireo_orbiter: IAlbireoDispatcher,
    pub deneb_orbiter: IDenebDispatcher
}

/// @custom:event NewShuttle Emitted when a new shuttle is deployed
#[derive(Drop, starknet::Event)]
pub struct NewShuttle {
    pub shuttle_id: u32,
    pub borrowable: IBorrowableDispatcher,
    pub collateral: ICollateralDispatcher
}

/// @custom:event NewDAOReserves Emitted when a new DAO Reserves contract is set
#[derive(Drop, starknet::Event)]
pub struct NewDAOReserves {
    pub old_dao_reserves: ContractAddress,
    pub new_dao_reserves: ContractAddress,
}

/// @custom:event SwitchOrbiterStatus Emitted when an orbiter is turned off or on
#[derive(Drop, starknet::Event)]
pub struct SwitchOrbiterStatus {
    pub orbiter_id: u32,
    pub status: bool,
}

/// @custom:event NewCygnusAltair Emitted when a new base altair router is set
#[derive(Drop, starknet::Event)]
pub struct NewCygnusAltair {
    pub old_cygnus_altair: ContractAddress,
    pub new_cygnus_altair: ContractAddress,
}

/// @custom:event NewCygnusX1Vault Emitted when a new vault is set
#[derive(Drop, starknet::Event)]
pub struct NewCygnusX1Vault {
    pub old_cygnus_x1_vault: ContractAddress,
    pub new_cygnus_x1_vault: ContractAddress,
}

/// @custom:event NewCygnusPillars Emitted when a new pillars is set
#[derive(Drop, starknet::Event)]
pub struct NewCygnusPillars {
    pub old_cygnus_pillars: ContractAddress,
    pub new_cygnus_pillars: ContractAddress,
}
