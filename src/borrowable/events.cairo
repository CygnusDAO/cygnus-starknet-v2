use starknet::{ContractAddress};

/// Transfer
#[derive(Drop, starknet::Event)]
pub struct Transfer {
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub value: u256
}

/// Approval
#[derive(Drop, starknet::Event)]
pub struct Approval {
    pub owner: ContractAddress,
    pub spender: ContractAddress,
    pub value: u256
}

// SyncBalance
#[derive(Drop, starknet::Event)]
pub struct SyncBalance {
    pub balance: u256
}

/// Deposit
#[derive(Drop, starknet::Event)]
pub struct Deposit {
    pub caller: ContractAddress,
    pub recipient: ContractAddress,
    pub assets: u256,
    pub shares: u256
}

/// Withdraw
#[derive(Drop, starknet::Event)]
pub struct Withdraw {
    pub caller: ContractAddress,
    pub recipient: ContractAddress,
    pub owner: ContractAddress,
    pub assets: u256,
    pub shares: u256
}

/// NewReserveFactor
#[derive(Drop, starknet::Event)]
pub struct NewReserveFactor {
    pub old_reserve_factor: u256,
    pub new_reserve_factor: u256
}

/// NewInterestRateModel
#[derive(Drop, starknet::Event)]
pub struct NewInterestRateModel {
    pub base_rate: u256,
    pub multiplier: u256,
    pub kink_muliplier: u256,
    pub kink: u256
}

/// AccrueInterest
#[derive(Drop, starknet::Event)]
pub struct AccrueInterest {
    pub cash: u256,
    pub borrows: u256,
    pub interest: u256,
    pub new_reserves: u256
}

/// Borrow
#[derive(Drop, starknet::Event)]
pub struct Borrow {
    pub caller: ContractAddress,
    pub borrower: ContractAddress,
    pub receiver: ContractAddress,
    pub borrow_amount: u256,
    pub repay_amount: u256
}

/// Liquidate
#[derive(Drop, starknet::Event)]
pub struct Liquidate {
    pub caller: ContractAddress,
    pub borrower: ContractAddress,
    pub receiver: ContractAddress,
    pub cyg_lp_amount: u256,
    pub max: u256,
    pub amount_usd: u256
}


/// Transfer
#[derive(Drop, starknet::Event)]
pub struct NewPillarsOfCreation {
    pub old_pillars: ContractAddress,
    pub new_pillars: ContractAddress,
}

