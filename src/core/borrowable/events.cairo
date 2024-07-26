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

/// NewReserveFactor
#[derive(Drop, starknet::Event)]
pub struct NewReserveFactor {
    pub old_reserve_factor: u128,
    pub new_reserve_factor: u128
}

/// NewInterestRateModel
#[derive(Drop, starknet::Event)]
pub struct NewInterestRateModel {
    pub base_rate: u128,
    pub multiplier: u128,
    pub kink_muliplier: u128,
    pub kink: u128
}

/// AccrueInterest
#[derive(Drop, starknet::Event)]
pub struct AccrueInterest {
    pub cash: u128,
    pub borrows: u128,
    pub interest: u128,
    pub new_reserves: u128
}

/// Borrow
#[derive(Drop, starknet::Event)]
pub struct Borrow {
    pub caller: ContractAddress,
    pub borrower: ContractAddress,
    pub receiver: ContractAddress,
    pub borrow_amount: u128,
    pub repay_amount: u128
}

/// Liquidate
#[derive(Drop, starknet::Event)]
pub struct Liquidate {
    pub caller: ContractAddress,
    pub borrower: ContractAddress,
    pub receiver: ContractAddress,
    pub cyg_lp_amount: u128,
    pub max: u128,
    pub amount_usd: u128
}


/// Transfer
#[derive(Drop, starknet::Event)]
pub struct NewPillarsOfCreation {
    pub old_pillars: ContractAddress,
    pub new_pillars: ContractAddress,
}

