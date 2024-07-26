//! Hangar18 Errors

/// Reverts if not called by the admin.
pub const ONLY_ADMIN: felt252 = 'hangar_only_admin';

/// Reverts if not called by the pending admin.
pub const ONLY_PENDING_ADMIN: felt252 = 'hangar_only_pending_admin';

/// Reverts if the orbiter is inactive during shuttle deployment.
pub const ORBITER_INACTIVE: felt252 = 'hangar_orbiter_inactive';

/// Reverts if deploying the same shuttle twice.
pub const SHUTTLE_ALREADY_DEPLOYED: felt252 = 'hangar_already_deployed';

/// Reverts if no oracle is set for this pair during shuttle deployment.
pub const ORACLE_NOT_INITIALIZED: felt252 = 'hangar_oracle_not_init';

/// Reverts if setting DAO reserves to zero. DAO Reserves can never be zero
pub const DAO_RESERVES_CANT_BE_ZERO: felt252 = 'hangar_invalid_dao_reserves';

/// Reverts if setting the pending admin to zero.
pub const PENDING_ADMIN_CANT_BE_ZERO: felt252 = 'hangar_pending_cant_be_0';

