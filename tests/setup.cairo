use cygnus::core::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
use cygnus::core::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};

use cygnus::core::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};
use cygnus::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
use cygnus::types::ekubo::{PoolKeyCYG};
use snforge_std::{
    declare, start_cheat_caller_address_global, stop_cheat_caller_address_global, ContractClassTrait, ContractClass
};
use starknet::{ContractAddress, contract_address_const};
use tests::users::{admin};

/// 1. Deploy orbiters
/// 2. Deploy oracle
/// 3. Deploy factory
/// 4. Initialize Deployers in factory

const FEED0: felt252 = 'ETH/USD';
const FEED1: felt252 = 'STRK/USD';

// test pool key
const TOKEN0: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
const TOKEN1: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
const FEE: felt252 = 34028236692093847977029636859101184;
const TICK_SPACING: felt252 = 200;
const EXTENSION: felt252 = 0;


/// Setup above
pub fn setup() -> IHangar18Dispatcher {
    let (albireo, deneb) = deploy_orbiters();
    let oracle: ICygnusNebulaDispatcher = deploy_oracle();
    let hangar18: IHangar18Dispatcher = deploy_factory(admin(), oracle);
    initialize_deployers(admin(), hangar18, albireo, deneb);
    initialize_oracle_for_pair(admin(), oracle);
    hangar18
}


fn deploy_orbiters() -> (IAlbireoDispatcher, IDenebDispatcher) {
    // Borrowable deployer
    let contract = declare("Albireo").unwrap();
    let borrowable_class_hash = declare("Borrowable").unwrap();
    let constructor_calldata = array![borrowable_class_hash.class_hash.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let albireo = IAlbireoDispatcher { contract_address };

    // Collateral deployer
    let contract = declare("Deneb").unwrap();
    let collateral_class_hash = declare("Collateral").unwrap();
    let constructor_calldata = array![collateral_class_hash.class_hash.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let deneb = IDenebDispatcher { contract_address };

    (albireo, deneb)
}

fn deploy_oracle() -> ICygnusNebulaDispatcher {
    let contract = declare("CygnusNebula").unwrap();
    let constructor_calldata = array![admin().into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    ICygnusNebulaDispatcher { contract_address }
}

fn deploy_factory(admin: ContractAddress, oracle: ICygnusNebulaDispatcher) -> IHangar18Dispatcher {
    let contract = declare("Hangar18").unwrap();
    let constructor_calldata = array![admin.into(), oracle.contract_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    IHangar18Dispatcher { contract_address }
}

fn initialize_deployers(
    admin: ContractAddress, factory: IHangar18Dispatcher, albireo: IAlbireoDispatcher, deneb: IDenebDispatcher
) {
    beep(admin);
    factory.set_orbiter('EkuboTest', albireo, deneb);
    boop();
}

fn initialize_oracle_for_pair(admin: ContractAddress, oracle: ICygnusNebulaDispatcher) {
    beep(admin);

    let pool_key: PoolKeyCYG = PoolKeyCYG {
        token0: TOKEN0.try_into().unwrap(),
        token1: TOKEN1.try_into().unwrap(),
        fee: FEE.try_into().unwrap(),
        tick_spacing: TICK_SPACING.try_into().unwrap(),
        extension: EXTENSION.try_into().unwrap(),
    };

    oracle.initialize_pool_oracle(pool_key, FEED0, FEED1);
    boop();
}

fn beep(user: ContractAddress) {
    start_cheat_caller_address_global(user);
}

fn boop() {
    stop_cheat_caller_address_global();
}
