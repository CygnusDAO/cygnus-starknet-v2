//use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
/// # Module
/// * `Collateral`
#[starknet::contract]
mod Collateral {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    use core::num::traits::Zero;
    use cygnus::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::collateral::errors::{REENTRANT_CALL, BORROWABLE_ALREADY_SET};
    use cygnus::collateral::events::{Transfer, Approval, SyncBalance, Deposit, Withdraw, Seize};
    use cygnus::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::utils::math::MathLib::MathLibTrait;
    use erc6909::token::erc6909::ERC6909Component;
    use erc6909::token::erc6909::extensions::ERC6909TokenSupplyComponent;
    use erc6909::token::erc6909::{ERC6909ABIDispatcher, ERC6909ABIDispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    /// ---------------------------- COMPONENT IMPLEMENTATION ----------------------------

    // Use ERC6909 and TokenSupply Components to represent ekubo positions
    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);
    component!(path: ERC6909TokenSupplyComponent, storage: erc6909_token_supply, event: ERC6909TokenSupplyEvent);

    // Embed component ABIs
    #[abi(embed_v0)]
    impl ERC6909MixinImpl = ERC6909Component::ERC6909MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909TokenSupplyImpl = ERC6909TokenSupplyComponent::ERC6909TokenSupplyImpl<ContractState>;

    // Internal implementation of components
    impl ERC6909InternalImpl = ERC6909Component::InternalImpl<ContractState>;
    impl ERC6909TokenSuppplyInternalImpl = ERC6909TokenSupplyComponent::InternalImpl<ContractState>;

    /// ---------------------------- IMPLEMENT SUPPLY HOOK ----------------------------

    impl ERC6909HooksImpl<
        TContractState,
        impl ERC6909TokenSupply: ERC6909TokenSupplyComponent::HasComponent<TContractState>,
        impl HasComponent: ERC6909Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC6909Component::ERC6909HooksTrait<TContractState> {
        fn before_update(
            ref self: ERC6909Component::ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        ) {}

        fn after_update(
            ref self: ERC6909Component::ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        ) {
            let mut erc6909_token_supply_component = get_dep_component_mut!(ref self, ERC6909TokenSupply);
            erc6909_token_supply_component._update_token_supply(from, recipient, id, amount);
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909Event: ERC6909Component::Event,
        #[flat]
        ERC6909TokenSupplyEvent: ERC6909TokenSupplyComponent::Event,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage,
        #[substorage(v0)]
        erc6909_token_supply: ERC6909TokenSupplyComponent::Storage,
        guard: bool,
        twin_star: IBorrowableDispatcher,
        hangar18: IHangar18Dispatcher,
        underlying: ERC6909ABIDispatcher,
        nebula: ICygnusNebulaDispatcher,
        shuttle_id: u32,
        total_balance: u256,
        debt_ratio: u256,
        liq_incentive: u256,
        liq_fee: u256,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hangar18: IHangar18Dispatcher,
        underlying: ERC6909ABIDispatcher,
        borrowable: IBorrowableDispatcher,
        oracle: ICygnusNebulaDispatcher,
        shuttle_id: u32
    ) {
        self._initialize(hangar18, underlying, borrowable, oracle, shuttle_id);
    }
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusCollateral of cygnus::collateral::interface::ICollateral<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                          TERMINAL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn underlying(self: @ContractState) -> ContractAddress {
            self.underlying.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn borrowable(self: @ContractState) -> ContractAddress {
            self.twin_star.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn nebula(self: @ContractState) -> ContractAddress {
            self.nebula.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn shuttle_id(self: @ContractState) -> u32 {
            self.shuttle_id.read()
        }

        /// # Implementation
        /// * ICollateral
        fn total_balance(self: @ContractState) -> u256 {
            20
        }

        /// # Implementation
        /// * ICollateral
        fn total_assets(self: @ContractState) -> u256 {
            20
        }

        /// # Implementation
        /// * ICollateral
        fn exchange_rate(self: @ContractState) -> u256 {
            20
        }

        /// Transfers LP from caller and mints them shares.
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn deposit(ref self: ContractState, assets: u256, recipient: ContractAddress) -> u256 {
            20
        }

        /// Converts `shares` to USDC assets, withdraws assets from zkLend's USDC pool
        /// and sends assets to `recipient`
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn redeem(ref self: ContractState, shares: u256, recipient: ContractAddress, owner: ContractAddress) -> u256 {
            20
        }

        /// # Implementation
        /// * ICollateral
        fn debt_ratio(self: @ContractState) -> u256 {
            self.debt_ratio.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_incentive(self: @ContractState) -> u256 {
            self.liq_incentive.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_fee(self: @ContractState) -> u256 {
            self.liq_fee.read()
        }


        /// Force a sync and update our total balance deposited in the strategy
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn sync(ref self: ContractState) {
            /// Lock
            self._lock();

            // Update, unlock
            self._update_and_unlock();
        }


        /// # Security
        /// * Checks that borrowable is the zero address before setting. Can only be set once!
        ///
        /// # Implementation
        /// * ICollateral
        fn set_borrowable(ref self: ContractState, borrowable: IBorrowableDispatcher) {
            /// # Error
            /// * `BORROWABLE_ALREADY_SET` - Reverts if borrowable is not zero
            assert(self.twin_star.read().contract_address.is_zero(), BORROWABLE_ALREADY_SET);

            /// Write borrowable to storage, cannot be set again
            self.twin_star.write(borrowable);
        }


        ///----------------------------------------------------------------------------------------------------
        ///                                          4. MODEL
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn can_borrow(self: @ContractState, borrower: ContractAddress, amount: u256) -> bool {
            false
        }

        /// # Implementation
        /// * ICollateral
        fn get_account_liquidity(self: @ContractState, borrower: ContractAddress) -> (u256, u256) {
            (10, 10)
        }

        /// # Implementation
        /// * ICollateral
        fn get_lp_token_price(self: @ContractState) -> u256 {
            10
        }

        /// # Implementation
        /// * ICollateral
        fn can_redeem(self: @ContractState, borrower: ContractAddress, amount: u256) -> bool {
            false
        }

        /// # Implementation
        /// * ICollateral
        fn get_borrower_position(self: @ContractState, borrower: ContractAddress) -> (u256, u256, u256) {
            (10, 10, 10)
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                          5. COLLATERAL
        ///----------------------------------------------------------------------------------------------------

        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn seize_cyg_lp(
            ref self: ContractState, liquidator: ContractAddress, borrower: ContractAddress, repay_amount: u256
        ) -> u256 {
            10
        }

        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn flash_redeem(
            ref self: ContractState, redeemer: ContractAddress, redeem_amount: u256, calldata: Array<felt252>
        ) -> u256 {
            10
        }
    }


    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    //      6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// -------------------------------------------------------------------------------------------------------
    ///                                          LOGIC - INITIALIZER
    /// -------------------------------------------------------------------------------------------------------

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _initialize(
            ref self: ContractState,
            hangar18: IHangar18Dispatcher,
            underlying: ERC6909ABIDispatcher,
            borrowable: IBorrowableDispatcher,
            oracle: ICygnusNebulaDispatcher,
            shuttle_id: u32
        ) {
            /// The factory used as control centre
            self.hangar18.write(hangar18);

            /// The underlying LP address
            self.underlying.write(underlying);

            /// The borrowable address
            self.twin_star.write(borrowable);

            /// The oracle used to price the LP
            self.nebula.write(oracle);

            /// The lending pool ID
            self.shuttle_id.write(shuttle_id);
        }
    }

    /// Utils
    #[generate_trait]
    impl UtilsImpl of UtilsTrait {
        /// Syncs the `total_balance` variable with the currently deposited cash in the strategy.
        #[inline(always)]
        fn _update(ref self: ContractState) {}

        /// It locks and accrues interest. After accrual we update the total_balance var to sync 
        /// our underlying balance with the strategy
        #[inline(always)]
        fn _lock(ref self: ContractState) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.guard.read(), REENTRANT_CALL);

            /// Lock
            self.guard.write(true);
        }

        /// Unlock and update our total_balance var after any payable action
        #[inline(always)]
        fn _update_and_unlock(ref self: ContractState) {
            /// Update after action
            self._update();

            /// Unlock
            self.guard.write(false);
        }
    }
}

