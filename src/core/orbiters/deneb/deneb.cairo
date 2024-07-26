/// Module - Collateral Deployer
#[starknet::contract]
mod Deneb {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    use core::poseidon::poseidon_hash_span;
    use cygnus::core::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::core::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::types::ekubo::{PoolKeyCYG};
    use starknet::syscalls::{deploy_syscall};
    use starknet::{ContractAddress, ClassHash, get_caller_address};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// The class hash of the collateral contract this orbiter deploys
        collateral_class_hash: ClassHash,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, class_hash: ClassHash) {
        self.collateral_class_hash.write(class_hash);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl DenebImpl of cygnus::core::orbiters::deneb::IDeneb<ContractState> {
        /// # Implementation
        /// * IDeneb
        fn collateral_class_hash(self: @ContractState) -> ClassHash {
            self.collateral_class_hash.read()
        }

        /// # Implementation
        /// * IDeneb
        fn deploy_collateral(
            ref self: ContractState,
            pool_key: PoolKeyCYG,
            borrowable: IBorrowableDispatcher,
            oracle: ContractAddress,
            shuttle_id: u32
        ) -> ICollateralDispatcher {
            // Get caller address (this should be the factory, but it's callable by anyone)
            let factory = get_caller_address();

            // 1. The class hash for the syscall
            let class = self.collateral_class_hash.read();

            // 2. Salt of collateral is always: [lp_token, hangar18]
            let salt = self.collateral_salt(pool_key, factory, shuttle_id);

            // 3. Build constructor arguments
            let calldata = self.c_calldata(factory, pool_key, borrowable, oracle, shuttle_id);

            // 4. Deploy collateral
            let (contract_address, _) = deploy_syscall(class, salt, calldata, false).unwrap();

            // Return new collateral address
            ICollateralDispatcher { contract_address }
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// The salt for deploying a new `Borrowable`
        ///
        /// # Arguments
        /// * `pool_key` - The Ekubo pool key
        /// * `sender` - The address of the msg.sender
        ///
        /// # Returns
        /// * The salt used to deploy the collateral
        fn collateral_salt(
            self: @ContractState, pool_key: PoolKeyCYG, sender: ContractAddress, shuttle_id: u32
        ) -> felt252 {
            /// Build salt for collateral with the arguments
            let mut data = array![];

            data.append('CYGNUS_COLLATERAL');
            data.append(pool_key.token0.into());
            data.append(pool_key.token1.into());
            data.append(sender.into());
            data.append(shuttle_id.into());

            // https://docs.starknet.io/documentation/architecture_and_concepts/Cryptography/hash-functions/
            poseidon_hash_span(data.span())
        }

        /// The constructor arguments for the collateral
        ///
        /// # Arguments
        /// * `factory` - The address of hangar18
        /// * `pool_key` - The Ekubo pool key
        /// * `borrowable` - The address of the borrowable contract
        /// * `oracle` - The address of the oracle for the collateral and collateral
        /// * `shuttle_id` - Unique lending pool ID, shared by the collateral
        ///
        /// # Returns
        /// * The spanned constructor arguments of the collateral
        fn c_calldata(
            self: @ContractState,
            factory: ContractAddress,
            pool_key: PoolKeyCYG,
            borrowable: IBorrowableDispatcher,
            oracle: ContractAddress,
            shuttle_id: u32
        ) -> Span<felt252> {
            // Build constructor arguments
            let mut constructor_calldata = array![];

            constructor_calldata.append(factory.into());
            constructor_calldata.append(pool_key.token0.into());
            constructor_calldata.append(pool_key.token1.into());
            constructor_calldata.append(pool_key.fee.into());
            constructor_calldata.append(pool_key.tick_spacing.into());
            constructor_calldata.append(pool_key.extension.into());
            constructor_calldata.append(borrowable.contract_address.into());
            constructor_calldata.append(oracle.into());
            constructor_calldata.append(shuttle_id.into());

            constructor_calldata.span()
        }
    }
}
