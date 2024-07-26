use cygnus::types::ekubo::{PoolKeyCYG, PositionKeyCYG};
use cygnus::types::nebula::{LPInfo, NebulaOracle};
use cygnus::types::pragma::{DataType};
use starknet::ContractAddress;

/// Ekubo oracle
#[starknet::interface]
pub trait ICygnusNebula<TState> {
    /// Name of the LP Oracle (ie. UniswapV2, UniswapV3, etc.)
    fn name(self: @TState) -> ByteArray;

    /// Decimals that this oracle uses
    fn decimals(self: @TState) -> u8;

    /// Mapping of Oracle ID => Oracle struct
    fn all_oracles(self: @TState, oracle_id: u8) -> NebulaOracle;

    /// Initalize the oracle 
    fn initialize_pool_oracle(ref self: TState, pool_key: PoolKeyCYG);

    /// Returns the price of a position denominated in USD
    fn position_price_usd(self: @TState, pool_key: PoolKeyCYG, position_key: PositionKeyCYG) -> u128;

    /// Returns the price of a saved NFT in USD
    fn nft_price_usd(self: @TState, nft_id: u64) -> u128;

    /// Mapping of LP address => Oracle struct
    fn nebula_oracle(self: @TState, pool_key: PoolKeyCYG) -> NebulaOracle;

    /// Returns the price of an asset from Pragma Oracle
    fn get_asset_price(self: @TState, asset: DataType) -> u128;

    /// Returns the denomination token price
    fn denomination_token_price(self: @TState) -> u128;

    /// Returns the decimals of a feed
    fn get_asset_decimals(self: @TState, asset: DataType) -> u32;
}
