/// Interest Rate Model
#[derive(Drop, starknet::Store, Serde)]
pub struct InterestRateModel {
    pub base_rate_per_second: u64,
    pub multiplier_per_second: u64,
    pub jump_multiplier_per_second: u64,
    pub kink: u64
}

/// Borrow Snapshot of each borrower across all pools
#[derive(Drop, Copy, starknet::Store, Serde)]
pub struct BorrowSnapshot {
    pub principal: u256,
    pub interest_index: u256,
}
