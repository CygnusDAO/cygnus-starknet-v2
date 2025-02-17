use ekubo::types::i129::i129;
use starknet::ContractAddress;

/// Epoch Information on each epoch
///
/// @param epoch The ID for this epoch
/// @param cyg_per_block The CYG reward rate for this epoch
/// @param total_rewards The total amount of CYG estimated to be rewarded in this epoch
/// @param total_claimed The total amount of claimed CYG
/// @param start The unix timestamp of when this epoch started
/// @param end The unix timestamp of when it ended or is estimated to end
#[derive(Copy, Drop, starknet::Store, Serde)]
struct EpochInfo {
    epoch: u8,
    cyg_per_block: u128,
    total_rewards: u128,
    total_claimed: u128,
    start: u64,
    end: u64
}

/// ShuttleInfo Info of each borrowable
///
/// active - Whether the pool is active or not
/// shuttle_id - The ID for this shuttle to identify in hangar18
/// borrowable - The address of this shuttle id's borrowable
/// collateral - The address of this shuttle id's collateral
/// total_shares - The total number of shares held in the pool
/// acc_reward_per_share - The accumulated reward per share
/// last_reward_time - The timestamp of the last reward distribution
/// alloc_point The allocation points of the pool
/// pillars_id - Unique ID for this shuttle (1 shuttle id = 2 pillars id)
#[derive(Copy, Drop, starknet::Store, Serde)]
struct ShuttleInfo {
    active: bool,
    shuttle_id: u32,
    borrowable: ContractAddress,
    collateral: ContractAddress,
    total_shares: u128,
    acc_reward_per_share: u128,
    last_reward_time: u64,
    alloc_point: u128,
    pillars_id: u32
}

/// UserInfo Info of each user
///
/// shares - The amount of shares of the user (for borrowers their borrow balance and for lenders their USD lend amount)
/// reward_debt - The amount of rewards debt for each user
#[derive(Drop, starknet::Store, Serde)]
struct UserInfo {
    shares: u128,
    reward_debt: i129
}
