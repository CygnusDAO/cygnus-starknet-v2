use cygnus::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

// Libraries
use starknet::{ClassHash, ContractAddress};

/// Interface - Borrowable Deployer
#[starknet::interface]
pub trait IAlbireo<T> {
    /// # Returns
    /// * The class hash of the borrowable contract this orbiter deploys
    fn borrowable_class_hash(self: @T) -> ClassHash;

    /// Deploys the borrowable contract with the collateral address
    ///
    /// # Arguments
    /// * `underlying` - The address of the underlying LP
    /// * `collateral` - The address of the collateral
    /// * `oracle` - The address of the oracle for the underlying
    /// * `shuttle_id` - Unique lending pool ID (shared with collateral)
    ///
    /// # Returns
    /// * The deployed borrowable contract
    fn deploy_borrowable(
        ref self: T,
        underlying: ContractAddress,
        collateral: ICollateralDispatcher,
        oracle: ContractAddress,
        shuttle_id: u32
    ) -> IBorrowableDispatcher;
}

