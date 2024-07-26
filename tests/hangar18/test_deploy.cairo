use cygnus::core::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::core::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
use cygnus::core::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use cygnus::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
use cygnus::types::ekubo::{PoolKeyCYG};
use snforge_std::{
    declare, start_cheat_caller_address_global, stop_cheat_caller_address_global, ContractClassTrait, ContractClass
};
use starknet::{ContractAddress, contract_address_const};

// Cygnus
use tests::setup::{setup};

//#[fork("MAINNET")]
#[test]
fn test_deployed_correctly() {
    let hangar18 = setup();
    assert(1 == 1, 'no');
}
