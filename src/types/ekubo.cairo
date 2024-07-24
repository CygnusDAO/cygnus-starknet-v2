use core::option::{Option, OptionTrait};
use core::traits::{Into, TryInto};
use ekubo::types::bounds::{Bounds};
use ekubo::types::i129::{i129};
use ekubo::types::keys::{PoolKey, PositionKey};
use starknet::Store;
use starknet::{contract_address_const, ContractAddress};

// Tick bounds for a position
#[derive(Copy, Drop, Serde, PartialEq, Hash, starknet::Store)]
pub struct BoundsCYG {
    pub lower: i129,
    pub upper: i129
}

// Uniquely identifies a pool
// token0 is the token with the smaller address (sorted by integer value)
// token1 is the token with the larger address (sorted by integer value)
// fee is specified as a 0.128 number, so 1% == 2**128 / 100
// tick_spacing is the minimum spacing between initialized ticks, i.e. ticks that positions may use
// extension is the address of a contract that implements additional functionality for the pool
#[derive(Copy, Drop, Serde, PartialEq, Hash, starknet::Store)]
pub struct PoolKeyCYG {
    pub token0: ContractAddress,
    pub token1: ContractAddress,
    pub fee: u128,
    pub tick_spacing: u128,
    pub extension: ContractAddress,
}

// salt is a random number specified by the owner to allow a single address to control many positions with the same pool and bounds
// owner is the immutable address of the position
// bounds is the price range where the liquidity of the position is active
#[derive(Copy, Drop, Serde, PartialEq, Hash, starknet::Store)]
pub struct PositionKeyCYG {
    pub salt: u64,
    pub owner: ContractAddress,
    pub bounds: BoundsCYG,
}

impl PoolKeyCYGImpl of Into<PoolKeyCYG, PoolKey> {
    fn into(self: PoolKeyCYG) -> PoolKey {
        PoolKey {
            token0: self.token0,
            token1: self.token1,
            fee: self.fee,
            tick_spacing: self.tick_spacing,
            extension: self.extension
        }
    }
}

impl BoundsCYGImpl of Into<BoundsCYG, Bounds> {
    fn into(self: BoundsCYG) -> Bounds {
        Bounds { lower: self.lower, upper: self.upper }
    }
}

impl PositionKeyCYGImpl of Into<PositionKeyCYG, PositionKey> {
    fn into(self: PositionKeyCYG) -> PositionKey {
        PositionKey { salt: self.salt, owner: self.owner, bounds: self.bounds.into() }
    }
}

