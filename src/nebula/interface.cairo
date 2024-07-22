use cygnus::types::nebula::{LPInfo, NebulaOracle};
use cygnus::types::pragma::{DataType};
use starknet::ContractAddress;

#[starknet::interface]
pub trait ICygnusNebula<TState> {
    /// Name of the LP Oracle (ie. UniswapV2, UniswapV3, etc.)
    fn name(self: @TState) -> felt252;

    /// Address of the registry, the owner of this oracle
    fn nebula_registry(self: @TState) -> ContractAddress;

    /// Decimals that this oracle uses
    fn decimals(self: @TState) -> u8;

    /// Returns the price of the 1 LP token denominated in the underlying
    fn lp_token_price(self: @TState, lp_token_pair: ContractAddress) -> u256;

    /// Initializes oracle, only callable from nebula registry
    fn initialize_oracle(ref self: TState, lp_token_pair: ContractAddress, price_feed0: felt252, price_feed1: felt252);

    /// Returns the price of an asset from Pragma Oracle
    fn get_asset_price(self: @TState, asset: DataType) -> u256;

    /// Returns the denomination token price
    fn denomination_token_price(self: @TState) -> u256;

    /// Returns LP Info, reporting
    fn lp_token_info(self: @TState, lp_token_pair: ContractAddress) -> LPInfo;

    /// Mapping of LP address => Oracle struct
    fn get_nebula_oracle(self: @TState, lp_token_pair: ContractAddress) -> NebulaOracle;

    /// Mapping of Oracle ID => Oracle struct
    fn all_oracles(self: @TState, oracle_id: u8) -> NebulaOracle;
}

