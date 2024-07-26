use cygnus::core::borrowable::IBorrowableDispatcher;
use cygnus::core::collateral::ICollateralDispatcher;
use openzeppelin::token::erc20::ERC20ABIDispatcher;
use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub(crate) struct FundX1VaultUSD {
    pub borrowable: IBorrowableDispatcher,
    pub dao_shares: u128,
    pub assets: u128,
}

#[derive(Drop, starknet::Event)]
pub(crate) struct FundX1VaultUSDAll {
    pub total_shuttles: u32,
    pub dao_shares: u128,
    pub assets: u128,
}

#[derive(Drop, starknet::Event)]
pub(crate) struct FundDAOSafeCygLP {
    pub dao_shares: u128
}

#[derive(Drop, starknet::Event)]
pub(crate) struct FundDAOSafeCygLPAll {
    pub total_shuttles: u32,
    pub dao_shares: u128
}

#[derive(Drop, starknet::Event)]
pub(crate) struct NewX1VaultWeight {
    pub old_weight: u128,
    pub new_weight: u128
}

#[derive(Drop, starknet::Event)]
pub(crate) struct CygTokenSet {
    pub cyg_token: ERC20ABIDispatcher,
}

#[derive(Drop, starknet::Event)]
pub(crate) struct PrivateBankerSwitch {
    pub private_banker: bool,
}

#[derive(Drop, starknet::Event)]
pub(crate) struct CygTokenClaim {
    pub to: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub(crate) struct NewDAOSafe {
    pub old_safe: ContractAddress,
    pub new_safe: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub(crate) struct NewX1Vault {
    pub old_vault: ContractAddress,
    pub new_vault: ContractAddress,
}

