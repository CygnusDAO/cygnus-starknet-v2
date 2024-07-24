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
    use cygnus::collateral::{errors, events};
    use cygnus::erc6909::extensions::ERC6909TokenSupplyComponent;
    use cygnus::erc6909::{ERC6909Component, ERC6909ABIDispatcher, ERC6909ABIDispatcherTrait};
    use cygnus::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::types::ekubo::{PoolKeyCYG, PositionKeyCYG};
    use cygnus::types::terminal::{DepositParams, RedeemParams, EkuboPosition};
    use cygnus::utils::addresses::{EKUBO_CORE, EKUBO_POSITIONS_NFT, EKUBO_POSITIONS};
    use cygnus::utils::math::MathLib::MathLibTrait;
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
    use ekubo::types::keys::{PoolKey, PositionKey};
    use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
    use openzeppelin::token::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    /// --------------------------------------------------------------------------------------------------------
    ///   Component implementations
    /// --------------------------------------------------------------------------------------------------------

    // We implement the ERC6909 component with the supply extension to keep track of id supplies
    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);
    component!(path: ERC6909TokenSupplyComponent, storage: erc6909_token_supply, event: ERC6909TokenSupplyEvent);

    // Embed the abi of each and implement the internal to mint/burn etc.
    #[abi(embed_v0)]
    impl ERC6909MixinImpl = ERC6909Component::ERC6909MixinImpl<ContractState>;
    impl ERC6909InternalImpl = ERC6909Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC6909TokenSupplyImpl = ERC6909TokenSupplyComponent::ERC6909TokenSupplyImpl<ContractState>;
    impl ERC6909TokenSuppplyInternalImpl = ERC6909TokenSupplyComponent::InternalImpl<ContractState>;

    // Implement the hooks to update token supplies
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
            id: u128,
            amount: u128
        ) {}

        fn after_update(
            ref self: ERC6909Component::ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u128,
            amount: u128
        ) {
            let mut erc6909_token_supply_component = get_dep_component_mut!(ref self, ERC6909TokenSupply);
            erc6909_token_supply_component._update_token_supply(from, recipient, id, amount);
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage,
        #[substorage(v0)]
        erc6909_token_supply: ERC6909TokenSupplyComponent::Storage,
        guard: bool,
        ekubo_core: ICoreDispatcher,
        ekubo_positions: IPositionsDispatcher,
        twin_star: IBorrowableDispatcher,
        hangar18: IHangar18Dispatcher,
        underlying: ERC721ABIDispatcher,
        nebula: ICygnusNebulaDispatcher,
        shuttle_id: u32,
        total_balance: LegacyMap<u64, u128>,
        debt_ratio: u128,
        liq_incentive: u128,
        liq_fee: u128,
        nft_position: LegacyMap<(ContractAddress, u128), EkuboPosition>,
        user_nft_positions: LegacyMap<ContractAddress, u128>,
        pool_key: PoolKeyCYG
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909Event: ERC6909Component::Event,
        #[flat]
        ERC6909TokenSupplyEvent: ERC6909TokenSupplyComponent::Event,
        SyncBalance: events::SyncBalance,
        Deposit: events::Deposit,
        Withdraw: events::Withdraw,
        NewDebtRatio: events::NewDebtRatio,
        NewLiquidationIncentive: events::NewLiquidationIncentive,
        NewLiquidationFee: events::NewLiquidationFee,
        Seize: events::Seize
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hangar18: IHangar18Dispatcher,
        pool_key: PoolKeyCYG,
        borrowable: IBorrowableDispatcher,
        oracle: ICygnusNebulaDispatcher,
        shuttle_id: u32
    ) {
        self._initialize(hangar18, pool_key, borrowable, oracle, shuttle_id);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl Collateral of cygnus::collateral::interface::ICollateral<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                          TERMINAL
        /// ---------------------------------------------------------------------------------------------------

        /// @inheritdoc ICollateral
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// @inheritdoc ICollateral
        fn pool_key(self: @ContractState) -> PoolKey {
            self.pool_key.read().into()
        }

        /// @inheritdoc ICollateral
        fn underlying(self: @ContractState) -> ContractAddress {
            self.underlying.read().contract_address
        }

        /// @inheritdoc ICollateral
        fn borrowable(self: @ContractState) -> ContractAddress {
            self.twin_star.read().contract_address
        }

        /// @inheritdoc ICollateral
        fn nebula(self: @ContractState) -> ContractAddress {
            self.nebula.read().contract_address
        }

        /// @inheritdoc ICollateral
        fn shuttle_id(self: @ContractState) -> u32 {
            self.shuttle_id.read()
        }

        /// @inheritdoc ICollateral
        fn total_balance(self: @ContractState, id: u64) -> u128 {
            self.total_balance.read(id)
        }

        /// @inheritdoc ICollateral
        fn total_assets(self: @ContractState) -> u128 {
            20
        }

        /// @inheritdoc ICollateral
        fn exchange_rate(self: @ContractState) -> u128 {
            20
        }

        /// @inheritdoc ICollateral
        fn on_erc721_received(
            self: @ContractState, operator: ContractAddress, from: ContractAddress, token_id: u128, data: Span<felt252>
        ) -> felt252 {
            IERC721_RECEIVER_ID
        }

        /// @inheritdoc ICollateral
        /// @custom:security Non-reentrant
        fn deposit(ref self: ContractState, params: DepositParams) -> u128 {
            // Lock
            self._lock();

            // Get position's liquidity to mint the equivalent in tokens
            let liquidity = self._get_position_liquidity(params.position_key);

            /// @cusotm:error Revert if minting 0 liquidity
            assert(liquidity > 0, errors::CANT_MINT_ZERO);

            // Transfer Ekubo NFT from caller to the vault
            let caller = get_caller_address();
            self.underlying.read().transfer_from(caller, get_contract_address(), params.token_id.into());

            // Mint unique position shares to recipient and store their position
            self.erc6909.mint(params.recipient, params.token_id.into(), liquidity);

            // Strategy (?)
            self._after_deposit(liquidity);

            /// @custom:event Deposit
            self.emit(events::Deposit { caller, liquidity, params });

            // Unlock and update
            self._update_and_unlock(params.token_id);

            liquidity
        }

        /// @inheritdoc ICollateral
        /// @custom:security Non-reentrant
        fn redeem(ref self: ContractState, params: RedeemParams) -> (u128, u128) {
            // Lock
            self._lock();

            // Check allowance for this position
            let caller = get_caller_address();
            if caller != params.owner {
                self.erc6909._spend_allowance(params.owner, caller, params.token_id.into(), params.liquidity);
            }

            /// @custom:error Revert if redeeming 0 tokens
            assert(params.liquidity != 0, errors::CANT_REDEEM_ZERO);

            /// Withdraw from strategy
            self._before_withdraw(params.liquidity);

            // Burn CygUSD and transfer stablecoin
            self.erc6909.burn(params.owner, params.token_id.into(), params.liquidity);

            let (amount0, amount1) = self
                .ekubo_positions
                .read()
                .withdraw(
                    params.token_id,
                    self.pool_key(),
                    params.position_key.bounds.into(),
                    params.liquidity,
                    params.min_token0,
                    params.min_token1,
                    true
                );

            /// Transfer usd to recipient
            //self.underlying.read().transfer_from(get_contract_address(), params.recipient, params.token_id.into());

            /// # Event
            /// * Withdraw
            //self.emit(Withdraw { caller, recipient: params.recipient, owner, assets, shares });

            // Unlock
            self._update_and_unlock(params.token_id);

            (amount0, amount1)
        }

        /// # Implementation
        /// * ICollateral
        fn debt_ratio(self: @ContractState) -> u128 {
            self.debt_ratio.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_incentive(self: @ContractState) -> u128 {
            self.liq_incentive.read()
        }

        /// # Implementation
        /// * ICollateral
        fn liquidation_fee(self: @ContractState) -> u128 {
            self.liq_fee.read()
        }


        /// Force a sync and update our total balance deposited in the strategy
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn sync(ref self: ContractState, token_id: u64) {
            /// Lock
            self._lock();

            // Update, unlock
            self._update_and_unlock(token_id);
        }


        /// # Security
        /// * Checks that borrowable is the zero address before setting. Can only be set once!
        ///
        /// # Implementation
        /// * ICollateral
        fn set_borrowable(ref self: ContractState, borrowable: IBorrowableDispatcher) {
            /// # Error
            /// * `BORROWABLE_ALREADY_SET` - Reverts if borrowable is not zero
            assert(self.twin_star.read().contract_address.is_zero(), errors::BORROWABLE_ALREADY_SET);

            /// Write borrowable to storage, cannot be set again
            self.twin_star.write(borrowable);
        }


        ///----------------------------------------------------------------------------------------------------
        ///                                          4. MODEL
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn can_borrow(self: @ContractState, borrower: ContractAddress, amount: u128) -> bool {
            false
        }

        /// # Implementation
        /// * ICollateral
        fn get_account_liquidity(self: @ContractState, borrower: ContractAddress) -> (u128, u128) {
            (10, 10)
        }

        /// # Implementation
        /// * ICollateral
        fn get_lp_token_price(self: @ContractState) -> u128 {
            10
        }

        /// # Implementation
        /// * ICollateral
        fn can_redeem(self: @ContractState, borrower: ContractAddress, amount: u128) -> bool {
            false
        }

        /// # Implementation
        /// * ICollateral
        fn get_borrower_position(self: @ContractState, borrower: ContractAddress) -> (u128, u128, u128) {
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
            ref self: ContractState, liquidator: ContractAddress, borrower: ContractAddress, repay_amount: u128
        ) -> u128 {
            10
        }

        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * ICollateral
        fn flash_redeem(
            ref self: ContractState, redeemer: ContractAddress, redeem_amount: u128, calldata: Array<felt252>
        ) -> u128 {
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
            pool_key: PoolKeyCYG,
            borrowable: IBorrowableDispatcher,
            oracle: ICygnusNebulaDispatcher,
            shuttle_id: u32,
        ) {
            /// The factory used as control centre
            self.hangar18.write(hangar18);

            // The unique Ekubo pool key
            self.pool_key.write(pool_key);

            /// For collateral the underlying is always the Ekubo NFT
            self.underlying.write(ERC721ABIDispatcher { contract_address: EKUBO_POSITIONS_NFT.try_into().unwrap() });

            /// The borrowable address
            self.twin_star.write(borrowable);

            /// The oracle used to price the LP
            self.nebula.write(oracle);

            /// The lending pool ID
            self.shuttle_id.write(shuttle_id);

            /// Core for positions
            self.ekubo_core.write(ICoreDispatcher { contract_address: EKUBO_CORE.try_into().unwrap() });
            self.ekubo_positions.write(IPositionsDispatcher { contract_address: EKUBO_POSITIONS.try_into().unwrap() });
        }
    }

    /// Terminal logic
    #[generate_trait]
    impl TerminalImpl of TerminalTrait {
        /// Checks that caller is admin
        fn _check_admin(self: @ContractState) {
            /// Get admin from factory
            let admin = self.hangar18.read().admin();

            /// # Error
            /// * `CALLER_NOT_ADMIN` - Reverts if caller is not hangar18's admin
            assert(get_caller_address() == admin, errors::CALLER_NOT_ADMIN);
        }

        ///// Convert CygLP shares to LP assets
        /////
        ///// # Arguments
        ///// * `shares` - The amount of CygLP shares to convert to LP
        /////
        ///// # Returns
        ///// * The assets equivalent of shares
        //#[inline(always)]
        //fn _convert_to_assets(self: @ContractState, id: u128, shares: u128) -> u128 {
        //    // Gas savings
        //    let supply = self.erc6909_token_supply.total_supply(id);

        //    // If no supply return shares 
        //    if supply == 0 {
        //        return shares;
        //    }

        //    // shares = shares * balance / supply
        //    shares.full_mul_div(self.total_balance.read(id), supply)
        //}

        ///// Convert LP assets to CygLP shares
        /////
        ///// # Arguments
        ///// * `assets` - The amount of LP assets to convert to CygLP shares
        /////
        ///// # Returns
        ///// * The shares equivalent of assets
        //#[inline(always)]
        //fn _convert_to_shares(self: @ContractState, id: u128, assets: u128) -> u128 {
        //    // Gas savings
        //    let supply = self.erc6909_token_supply.total_supply(id);

        //    // If no supply return assets
        //    if supply == 0 {
        //        return assets;
        //    }

        //    // shares = assets * supply / balance
        //    assets.full_mul_div(supply, self.total_balance.read(id))
        //}
    }

    #[generate_trait]
    impl VoidImpl of VoidTrait {
        /// @notice Gets the liquidity of a position from Ekubo
        #[inline(always)]
        fn _preview_total_balance(ref self: ContractState, token_id: u128) -> u128 {
            //TODO
            10
        }


        // Mmaybe here we update user positions? TODO
        #[inline(always)]
        fn _after_deposit(ref self: ContractState, amount: u128) {}

        /// Hook that handles underlying withdrawals from the strategy
        ///
        /// # Arguments
        /// * `amount` - The amount of underlying LP to deposit into the strategy
        #[inline(always)]
        fn _before_withdraw(ref self: ContractState, amount: u128) { /// Jediswap has no strategy
        }
    }

    /// Utils
    #[generate_trait]
    impl UtilsImpl of UtilsTrait {
        #[inline(always)]
        fn _update_user_positions(self: @ContractState, user: ContractAddress) -> u128 {
            self.user_nft_positions.read(user)
        }

        #[inline(always)]
        fn _get_position_liquidity(self: @ContractState, position_key: PositionKeyCYG) -> u128 {
            // Get the position's liquidity
            self.ekubo_core.read().get_position(self.pool_key.read().into(), position_key.into()).liquidity
        }

        /// Syncs the `total_balance` variable with the currently deposited cash in the strategy.
        #[inline(always)]
        fn _update(ref self: ContractState, token_id: u64) {
            /// Get our cash currently deposited in the strategy
            let balance = 10; //self._preview_total_balance();

            /// Update cash to storage
            self.total_balance.write(token_id, balance);

            /// # Event
            /// * `SyncBalance`
            self.emit(events::SyncBalance { balance });
        }

        /// It locks and accrues interest. After accrual we update the total_balance var to sync 
        /// our underlying balance with the strategy
        #[inline(always)]
        fn _lock(ref self: ContractState) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.guard.read(), errors::REENTRANT_CALL);

            /// Lock
            self.guard.write(true);
        }

        /// Unlock and update our total_balance var after any payable action
        #[inline(always)]
        fn _update_and_unlock(ref self: ContractState, token_id: u64) {
            /// Update after action
            self._update(token_id);

            /// Unlock
            self.guard.write(false);
        }
    }
}

