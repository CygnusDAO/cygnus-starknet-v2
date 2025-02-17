use starknet::{ContractAddress, contract_address_const};

pub fn admin() -> ContractAddress {
    0x666.try_into().unwrap()
}

// NFT depositor
pub fn borrower() -> ContractAddress {
    contract_address_const::<0x0400ebcbb957e9821b0c08d211899dfcadccae07044c6d470cdc3663e6ed43d4>()
}

// USDC whale
pub fn lender() -> ContractAddress {
    contract_address_const::<0x059ddf33b7eb8a80c7772adcef1950000225fae213d07b872166efcf07acb897>()
}

pub fn dao_reserves_contract() -> ContractAddress {
    0xda0.try_into().unwrap()
}
