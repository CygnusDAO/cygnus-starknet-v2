// Collateral arm of the pool
pub mod collateral;
pub mod errors;
pub mod events;
pub mod interface;

pub use interface::{ICollateral, ICollateralDispatcherTrait, ICollateralDispatcher};
