//! Albireo

/// Module - Borrowable Deployer
#[starknet::contract]
mod Albireo {
    /// # Libraries
    use core::poseidon::poseidon_hash_span;
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use cygnus::core::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::core::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use starknet::syscalls::{deploy_syscall};
    use starknet::{ContractAddress, ClassHash, get_caller_address};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// The class hash of the borrowable contract this orbiter deploys
        borrowable_class_hash: ClassHash,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, class_hash: ClassHash) {
        self.borrowable_class_hash.write(class_hash);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl AlbireoImpl of cygnus::core::orbiters::albireo::IAlbireo<ContractState> {
        /// # Implementation
        /// * IAlbireo
        fn borrowable_class_hash(self: @ContractState) -> ClassHash {
            self.borrowable_class_hash.read()
        }

        /// # Implementation
        /// * IAlbireo
        fn deploy_borrowable(
            ref self: ContractState,
            underlying: ContractAddress,
            collateral: ICollateralDispatcher,
            oracle: ContractAddress,
            shuttle_id: u32
        ) -> IBorrowableDispatcher {
            // Get caller address (this should be the factory)
            let factory = get_caller_address();

            // 1. The class hash for the syscall
            let class = self.borrowable_class_hash.read();

            // 2. Salt of borrowable is always: [collateral, hangar18]
            let salt = self.borrowable_salt(collateral, factory);

            // 3. Build constructor arguments
            let calldata = self.b_calldata(factory, underlying, collateral, oracle, shuttle_id);

            // 4. Deploy borrowable
            let (contract_address, _) = deploy_syscall(class, salt, calldata, false).unwrap();

            // Return new borrowable address
            IBorrowableDispatcher { contract_address }
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
        /// * `underlying` - The address of the underlying stablecoin
        /// * `collateral` - The address of the collateral contract
        /// * `oracle` - The address of the oracle for the collateral and borrowable
        /// * `shuttle_id` - Unique lending pool ID, shared by the collateral
        ///
        /// # Returns
        /// * The salt used to deploy the borrowable
        fn borrowable_salt(
            self: @ContractState, collateral: ICollateralDispatcher, sender: ContractAddress,
        ) -> felt252 {
            let mut data = array![];
            data.append('CYGNUS_BORROWABLE');
            data.append(collateral.contract_address.into());
            data.append(sender.into());
            poseidon_hash_span(data.span())
        }

        /// The constructor arguments for the borrowable
        ///
        /// # Arguments
        /// * `factory` - The address of hangar18
        /// * `underlying` - The address of the underlying stablecoin
        /// * `collateral` - The address of the collateral contract
        /// * `oracle` - The address of the oracle for the collateral and borrowable
        /// * `shuttle_id` - Unique lending pool ID, shared by the collateral
        ///
        /// # Returns
        /// * The spanned constructor arguments of the borrowable
        fn b_calldata(
            self: @ContractState,
            factory: ContractAddress,
            underlying: ContractAddress,
            collateral: ICollateralDispatcher,
            oracle: ContractAddress,
            shuttle_id: u32
        ) -> Span<felt252> {
            // Build constructor arguments
            let mut constructor_calldata = array![];
            constructor_calldata.append(factory.into());
            constructor_calldata.append(underlying.into());
            constructor_calldata.append(collateral.contract_address.into());
            constructor_calldata.append(oracle.into());
            constructor_calldata.append(shuttle_id.into());
            constructor_calldata.span()
        }
    }
}
