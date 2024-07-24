use cygnus::types::ekubo::{PoolKeyCYG, PositionKeyCYG};
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq, Hash, starknet::Store)]
pub struct EkuboPosition {
    pub token_id: u64,
    pub recipient: ContractAddress,
    pub pool_key: PoolKeyCYG,
    pub position_key: PositionKeyCYG
}

#[derive(Copy, Drop, Serde, PartialEq, Hash)]
pub struct DepositParams {
    pub token_id: u64,
    pub recipient: ContractAddress,
    pub position_key: PositionKeyCYG
}


#[derive(Copy, Drop, Serde, PartialEq, Hash)]
pub struct RedeemParams {
    pub token_id: u64,
    pub owner: ContractAddress,
    pub recipient: ContractAddress,
    pub liquidity: u128,
    pub min_token0: u128,
    pub min_token1: u128,
    pub position_key: PositionKeyCYG
}
