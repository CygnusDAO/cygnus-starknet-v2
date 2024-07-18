// Imports
use cygnus::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

// Libraries
use starknet::{ClassHash, ContractAddress};

/// Interface - Collateral Deployer
#[starknet::interface]
pub trait IDeneb<T> {
    /// # Returns
    /// * The class hash of the collateral contract this orbiter deploys
    fn collateral_class_hash(self: @T) -> ClassHash;

    /// Deploys the collateral contract with the borrowable address
    ///
    /// # Arguments
    /// * `underlying` - The address of the underlying LP
    /// * `borrowable` - The address of the borrowable
    /// * `oracle` - The address of the oracle for the underlying
    /// * `shuttle_id` - Unique lending pool ID (shared with borrowable)
    ///
    /// # Returns
    /// * The deployed collateral contract
    fn deploy_collateral(
        ref self: T,
        underlying: ContractAddress,
        borrowable: IBorrowableDispatcher,
        oracle: ContractAddress,
        shuttle_id: u32
    ) -> ICollateralDispatcher;
}
