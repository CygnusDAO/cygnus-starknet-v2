/// Deployers
use cygnus::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};

/// Shuttle struct
#[derive(Drop, starknet::Store, Serde)]
pub struct Shuttle {
    pub deployed: bool,
    pub shuttle_id: u32,
    pub borrowable: IBorrowableDispatcher,
    pub collateral: ICollateralDispatcher,
    pub orbiter_id: u32
}

/// DAOReserves struct
#[derive(Drop, starknet::Store, Serde)]
pub struct ShuttleDAOReserves {
    pub shuttle_id: u32,
    pub borrowable: IBorrowableDispatcher,
    pub collateral: ICollateralDispatcher,
}
