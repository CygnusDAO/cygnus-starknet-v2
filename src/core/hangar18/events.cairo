//! Hangar18 Events

/// Imports
use starknet::ContractAddress;

/// Emitted when a new factory admin is set.
#[derive(Drop, starknet::Event)]
pub struct NewAdmin {
    /// The address of the old admin.
    pub old_admin: ContractAddress,
    /// The address of the new admin.
    pub new_admin: ContractAddress,
}

/// Emitted when a new factory pending admin is set.
#[derive(Drop, starknet::Event)]
pub struct NewPendingAdmin {
    /// The address of the old pending admin.
    pub old_pending_admin: ContractAddress,
    /// The address of the new pending admin.
    pub new_pending_admin: ContractAddress,
}

/// Emitted when a new orbiter is set.
#[derive(Drop, starknet::Event)]
pub struct NewOrbiter {
    /// The ID of the orbiter.
    pub orbiter_id: u32,
    /// The dispatcher for the Albireo orbiter.
    pub albireo_orbiter: cygnus::core::orbiters::albireo::IAlbireoDispatcher,
    /// The dispatcher for the Deneb orbiter.
    pub deneb_orbiter: cygnus::core::orbiters::deneb::IDenebDispatcher,
}

/// Emitted when a new shuttle is deployed.
#[derive(Drop, starknet::Event)]
pub struct NewShuttle {
    /// The ID of the shuttle.
    pub shuttle_id: u32,
    /// The dispatcher for the borrowable component.
    pub borrowable: cygnus::core::borrowable::IBorrowableDispatcher,
    /// The dispatcher for the collateral component.
    pub collateral: cygnus::core::collateral::ICollateralDispatcher,
}

/// Emitted when a new DAO Reserves contract is set.
#[derive(Drop, starknet::Event)]
pub struct NewDAOReserves {
    /// The address of the old DAO Reserves contract.
    pub old_dao_reserves: ContractAddress,
    /// The address of the new DAO Reserves contract.
    pub new_dao_reserves: ContractAddress,
}

/// Emitted when an orbiter is turned off or on.
#[derive(Drop, starknet::Event)]
pub struct SwitchOrbiterStatus {
    /// The ID of the orbiter.
    pub orbiter_id: u32,
    /// The new status of the orbiter (true for on, false for off).
    pub status: bool,
}

/// Emitted when a new base Altair router is set.
#[derive(Drop, starknet::Event)]
pub struct NewCygnusAltair {
    /// The address of the old base Altair router.
    pub old_cygnus_altair: ContractAddress,
    /// The address of the new base Altair router.
    pub new_cygnus_altair: ContractAddress,
}

/// Emitted when a new vault is set.
#[derive(Drop, starknet::Event)]
pub struct NewCygnusX1Vault {
    /// The address of the old vault.
    pub old_cygnus_x1_vault: ContractAddress,
    /// The address of the new vault.
    pub new_cygnus_x1_vault: ContractAddress,
}

/// Emitted when new pillars are set.
#[derive(Drop, starknet::Event)]
pub struct NewCygnusPillars {
    /// The address of the old pillars.
    pub old_cygnus_pillars: ContractAddress,
    /// The address of the new pillars.
    pub new_cygnus_pillars: ContractAddress,
}

