use starknet::ContractAddress;

#[derive(Drop, Serde, Copy)]
pub enum Aggregator {
    #[default]
    JEDISWAP,
    EKUBO,
    AVNU,
    FIBROUS,
}

#[derive(Drop, Serde)]
pub struct LeverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    lp_amount_min: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>
}

#[derive(Drop, Serde)]
pub struct DeleverageCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    cyg_lp_amount: u128,
    usd_amount_min: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>
}

#[derive(Drop, Serde)]
pub struct LiquidateCalldata {
    lp_token_pair: ContractAddress,
    collateral: ContractAddress,
    borrowable: ContractAddress,
    recipient: ContractAddress,
    borrower: ContractAddress,
    repay_amount: u128,
    aggregator: Aggregator,
    swapdata: Array<Span<felt252>>
}

// LENS

#[derive(Drop, Serde)]
pub struct ShuttleInfoC {
    shuttle_id: u32,
    total_supply: u128,
    total_balance: u128,
    total_assets: u128,
    exchange_rate: u128,
    debt_ratio: u128,
    liquidation_fee: u128,
    liquidation_incentive: u128,
    lp_token_price: u128
}

#[derive(Drop, Serde)]
pub struct ShuttleInfoB {
    shuttle_id: u32,
    total_supply: u128,
    total_balance: u128,
    total_borrows: u128,
    total_assets: u128,
    exchange_rate: u128,
    reserve_factor: u128,
    utilization_rate: u128,
    supply_rate: u128,
    borrow_rate: u128,
    usd_price: u128
}

#[derive(Drop, Serde)]
pub struct BorrowerPosition {
    shuttle_id: u32,
    position_lp: u128,
    position_usd: u128,
    health: u128,
    cyg_lp_balance: u128,
    principal: u128,
    borrow_balance: u128,
    lp_token_price: u128,
    liquidity: u128,
    shortfall: u128,
    exchange_rate: u128,
}

#[derive(Drop, Serde)]
pub struct LenderPosition {
    shuttle_id: u32,
    cyg_usd_balance: u128,
    position_usdc: u128,
    position_usd: u128,
    usd_price: u128,
    exchange_rate: u128,
}

#[derive(Drop, Serde)]
pub struct ShuttlePositions {
    borrower: ContractAddress,
    cyg_lp_balance: u128,
    position_lp: u128,
    position_usd: u128,
    borrow_balance: u128,
    health: u128,
}

