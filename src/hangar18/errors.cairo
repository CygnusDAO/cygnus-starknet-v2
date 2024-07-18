// Hangar18 Errors

/// @custom:error ONLY_ADMIN Reverts if not called by admin
pub const ONLY_ADMIN: felt252 = 'hangar_only_admin';

/// @custom:error ONLY_PENDING_ADMIN Reverts if not called by pending admin
pub const ONLY_PENDING_ADMIN: felt252 = 'hangar_only_pending_admin';

/// @custom:error ORBITER_INACTIVE Reverts if orbiter is inactive
pub const ORBITER_INACTIVE: felt252 = 'hangar_orbiter_inactive';

/// @custom:error SHUTTLE_ALREADY_DEPLOYED Reverts if deploying the same shuttle twice
pub const SHUTTLE_ALREADY_DEPLOYED: felt252 = 'hangar_already_deployed';

/// @custom:error ORACLE_NOT_INITIALIZED Reverts if no oracle is set for this pair
pub const ORACLE_NOT_INITIALIZED: felt252 = 'hangar_oracle_not_init';

/// @custom:error DAO_RESERVES_CANT_BE_ZERO Reverts if setting dao reserves as 0
pub const DAO_RESERVES_CANT_BE_ZERO: felt252 = 'hangar_invalid_dao_reserves';

/// @custom:error PENDING_ADMIN_CANT_BE_ZERO Reverts if setting pending admin as 0
pub const PENDING_ADMIN_CANT_BE_ZERO: felt252 = 'hangar_pending_cant_be_0';
