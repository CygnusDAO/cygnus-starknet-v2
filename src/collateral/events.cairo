use starknet::{ContractAddress};

/// Transfer
#[derive(Drop, starknet::Event)]
pub struct Transfer {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub value: u128
}

/// Approval
#[derive(Drop, starknet::Event)]
pub struct Approval {
    pub owner: ContractAddress,
    pub spender: ContractAddress,
    pub value: u128
}

// SyncBalance
#[derive(Drop, starknet::Event)]
pub struct SyncBalance {
    pub balance: u128
}

/// Deposit
#[derive(Drop, starknet::Event)]
pub struct Deposit {
    pub caller: ContractAddress,
    pub recipient: ContractAddress,
    pub assets: u128,
    pub shares: u128
}

/// Withdraw
#[derive(Drop, starknet::Event)]
pub struct Withdraw {
    pub caller: ContractAddress,
    pub recipient: ContractAddress,
    pub owner: ContractAddress,
    pub assets: u128,
    pub shares: u128
}


/// NewLiquidationFee
#[derive(Drop, starknet::Event)]
pub struct NewLiquidationFee {
    pub old_liq_fee: u128,
    pub new_liq_fee: u128
}

/// NewLiqIncentive
#[derive(Drop, starknet::Event)]
pub struct NewLiquidationIncentive {
    pub old_incentive: u128,
    pub new_incentive: u128
}


/// NewDebtRatio
#[derive(Drop, starknet::Event)]
pub struct NewDebtRatio {
    pub old_ratio: u128,
    pub new_ratio: u128
}

/// Seize
#[derive(Drop, starknet::Event)]
pub struct Seize {
    pub liquidator: ContractAddress,
    pub borrower: ContractAddress,
    pub cyg_lp_amount: u128
}

