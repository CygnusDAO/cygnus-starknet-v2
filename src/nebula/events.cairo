use cygnus::types::ekubo::{PoolKeyCYG};
use starknet::ContractAddress;

/// # Event
/// * `NewLPOracle`
#[derive(Drop, starknet::Event)]
pub struct NewLPOracle {
    pub pool_key: PoolKeyCYG
}
