use cygnus::types::ekubo::{PoolKeyCYG};
use starknet::ContractAddress;

#[derive(Drop, starknet::Store, Serde, Copy)]
pub struct NebulaOracle {
    pub initialized: bool,
    pub oracle_id: u8,
    pub price_feed0: felt252,
    pub price_feed1: felt252,
    pub pool_key: PoolKeyCYG
}

#[derive(Drop, Serde)]
pub struct LPInfo {
    token0: ContractAddress,
    token1: ContractAddress,
    token0_price: u128,
    token1_price: u128,
    token0_reserves: u128,
    token1_reserves: u128,
    token0_decimals: u64,
    token1_decimals: u64,
    reserves0_usd: u128,
    reserves1_usd: u128
}
