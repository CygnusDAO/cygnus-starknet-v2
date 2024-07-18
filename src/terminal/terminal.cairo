// Imports
use starknet::ContractAddress;

/// # Component
/// * `TerminalComponent`
#[starknet::component]
mod TerminalComponent {
    use cygnus::hangar18::IHangar18Dispatcher;
    use cygnus::terminal::errors::Errors;
    use cygnus::terminal::events::Events::{SyncBalance, Deposit, Withdraw};
    use cygnus::terminal::interface::ITerminal;
    use erc6909::token::erc6909::{ERC6909Component, ERC6909HooksEmptyImpl};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Interfaces
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909Event: ERC6909Component::Event,
        SyncBalance: SyncBalance,
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        /// Non-reentrant guard
        guard: bool,
        /// Opposite arm (ie. borrowable)
        twin_star: ContractAddress,
        /// The address of the factory
        hangar18: IHangar18Dispatcher,
        /// The address of the underlying asset (ie an LP Token)
        underlying: ContractAddress,
        /// The address of the oracle for this lending pool
        nebula: ContractAddress,
        /// The lending pool ID (shared by the borrowable)
        shuttle_id: u32,
        /// Total balance of the underlying deposited in the strategy (ie. total cash)
        total_balance: u128,
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    // TODO
    // #[constructor]
    // fn constructor(
    //     ref self: ComponentState,
    //     hangar18: IHangar18Dispatcher,
    //     underlying: IERC6909Dispatcher,
    //     borrowable: IERC6909Dispatcher,
    //     oracle: INebulaDispatcher,
    //     shuttle_id: u32
    // ) {
    //     self._initialize(hangar18, underlying, borrowable, oracle, shuttle_id);
    // }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[embeddable_as(TerminalImpl)]
    impl Terminal<TContractState, +HasComponent<TContractState>> of ITerminal<ComponentState<TContractState>> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                          2. TERMINAL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICollateral
        fn hangar18(self: @ComponentState<TContractState>) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn underlying(self: @ComponentState<TContractState>) -> ContractAddress {
            self.underlying.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn nebula(self: @ComponentState<TContractState>) -> ContractAddress {
            self.nebula.read().contract_address
        }

        /// # Implementation
        /// * ICollateral
        fn shuttle_id(self: @ComponentState<TContractState>) -> u32 {
            self.shuttle_id.read()
        }

        /// # Implementation
        /// * ICollateral
        fn total_balance(self: @ComponentState<TContractState>) -> u128 {
            self.total_balance.read()
        }

        /// Kept here for consistency with borrowable, for collateral total assets is just total balance of LPs
        ///
        /// # Implementation
        /// * ICollateral
        fn total_assets(self: @ComponentState<TContractState>) -> u128 {
            self.total_balance.read()
        }

        /// # Implementation
        /// * ICollateral
        fn exchange_rate(self: @ComponentState<TContractState>) -> u128 {
            /// Get supply of CygLP
            let supply = self.total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return 1_000_000_000_000_000_000;
            }

            /// Return the exhcange rate between 1 CygLP and LP assets (ie. how much LP can be redeemed
            /// for 1 unit of CygLP)
            return self.total_assets().div_wad(supply);
        }

        /// Transfers LP from caller and mints them shares.
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn deposit(ref self: ComponentState<TContractState>, assets: u128, recipient: ContractAddress) -> u128 {
            /// Lock
            self._lock();

            /// Convert underlying assets to CygLP shares
            let mut shares = self._convert_to_shares(assets);

            /// # Error
            /// * `CANT_MINT_ZERO` - Reverts if minting 0 shares
            assert(shares > 0, Errors::CANT_MINT_ZERO);

            /// Get caller address and contract address
            let caller = get_caller_address();
            let receiver = get_contract_address();

            // Transfer LPs to vault
            self.underlying.read().transferFrom(caller, receiver, assets.into());

            // Burn 1000 shares to address zero, this is only for the first depositor
            if (self.total_supply.read() == 0) {
                shares -= 1000;
                self._mint(Zeroable::zero(), 1000);
            }

            /// Mint CygLP
            self._mint(recipient, shares);

            /// Deposit USDC in strategy
            self._after_deposit(assets);

            /// # Event
            /// * Deposit
            self.emit(Deposit { caller, recipient, assets, shares });

            /// Unlock and update
            self._update_and_unlock();

            shares
        }

        /// Converts `shares` to USDC assets, withdraws assets from zkLend's USDC pool
        /// and sends assets to `recipient`
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn redeem(
            ref self: ComponentState<TContractState>, shares: u128, recipient: ContractAddress, owner: ContractAddress
        ) -> u128 {
            /// Locks, accrues and updates our balance
            self._lock();

            /// Get sender
            let caller = get_caller_address();

            /// Check for allowance
            if caller != owner {
                self._spend_allowance(owner, caller, shares);
            }

            /// Convert to assets
            let assets = self._convert_to_assets(shares);

            /// # Error
            /// * `CANT_REDEEM_ZERO` - Avoid withdrawing 0 assets
            assert(assets != 0, Errors::CANT_REDEEM_ZERO);

            /// Withdraw from strategy
            self._before_withdraw(assets);

            // Burn CygUSD and transfer stablecoin
            self._burn(owner, shares);

            /// Transfer usd to recipient
            self.underlying.read().transfer(recipient, assets.into());

            /// # Event
            /// * Withdraw
            self.emit(Withdraw { caller, recipient, owner, assets, shares });

            // Unlock
            self._update_and_unlock();

            assets
        }

        /// Force a sync and update our total balance deposited in the strategy
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn sync(ref self: ComponentState<TContractState>) {
            /// Lock
            self._lock();

            // Update, unlock
            self._update_and_unlock();
        }
    }


    /// Utils
    #[generate_trait]
    pub impl InternalImpl<TContractState, +HasComponent<TContractState>> of InternalTrait<TContractState> {
        /// It locks and accrues interest. After accrual we update the total_balance var to sync 
        /// our underlying balance with the strategy
        fn _lock(ref self: ComponentState<TContractState>) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.guard.read(), Errors::REENTRANT_CALL);

            /// Lock
            self.guard.write(true);
        }

        /// Unlock and update our total_balance var after any payable action
        fn _update_and_unlock(ref self: ComponentState<TContractState>) {
            /// Update after action
            self._update();

            /// Unlock
            self.guard.write(false);
        }
    }
}
