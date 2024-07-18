pub mod Events {
    use starknet::ContractAddress;

    // SyncBalance
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct SyncBalance {
        balance: u128
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Deposit {
        caller: ContractAddress,
        recipient: ContractAddress,
        assets: u128,
        shares: u128
    }

    /// Withdraw
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Withdraw {
        caller: ContractAddress,
        recipient: ContractAddress,
        owner: ContractAddress,
        assets: u128,
        shares: u128
    }
}
//pub use Events::{SyncBalance, Deposit, Withdraw};


