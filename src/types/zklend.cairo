use starknet::ContractAddress;

#[starknet::interface]
pub trait IZKLendMarket<TContractState> {
    /// Deposit a token into a market
    fn deposit(ref self: TContractState, token: ContractAddress, amount: felt252);

    /// Withdraw a token from a market
    fn withdraw(ref self: TContractState, token: ContractAddress, amount: felt252);

    /// Get our balance of zTOKEN
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait IZKToken<TContractState> {
    /// Get our balance of zTOKEN
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
}
