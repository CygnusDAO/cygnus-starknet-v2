/// # Module
/// * `Collateral`
#[starknet::contract]
mod Collateral {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    use core::integer::BoundedInt;
    use core::num::traits::Zero;
    use cygnus::borrowable::errors;
    use cygnus::borrowable::events;
    use cygnus::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::periphery::altair::{IAltairDispatcher, IAltairDispatcherTrait};
    use cygnus::types::interest::{InterestRateModel, BorrowSnapshot};
    use cygnus::types::zklend::{IZKLendMarketDispatcher, IZKLendMarketDispatcherTrait};
    use cygnus::utils::math::MathLib::MathLibTrait;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    /// ---------------------------- COMPONENT IMPLEMENTATION ----------------------------

    // Use ERC20 Component from OZ
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // Embed component ABIs
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Internal implementation of components
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        SyncBalance: events::SyncBalance,
        Deposit: events::Deposit,
        Withdraw: events::Withdraw,
        NewReserveFactor: events::NewReserveFactor,
        NewInterestRateModel: events::NewInterestRateModel,
        NewPillarsOfCreation: events::NewPillarsOfCreation,
        AccrueInterest: events::AccrueInterest,
        Borrow: events::Borrow,
        Liquidate: events::Liquidate
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        guard: bool,
        twin_star: ICollateralDispatcher,
        hangar18: IHangar18Dispatcher,
        underlying: ERC20ABIDispatcher,
        nebula: ICygnusNebulaDispatcher,
        shuttle_id: u32,
        total_balance: u128,
        pillars_of_creation: ContractAddress,
        interest_rate_model: InterestRateModel,
        reserve_factor: u128,
        borrow_balances: LegacyMap<ContractAddress, BorrowSnapshot>,
        last_accrual_timestamp: u64,
        total_borrows: u128,
        borrow_index: u128,
        zk_lend_market: IZKLendMarketDispatcher,
        zk_lend_usdc: ERC20ABIDispatcher,
    }

    /// The maximum possible base rate set by admin
    const BASE_RATE_MAX: u128 = 100000000000000000; // 0.1e18 = 10%
    /// The minimum possible kink util rate
    const KINK_UTIL_MIN: u128 = 700000000000000000; // 0.7e18 = 70%
    /// The maximum possible kink util rate
    const KINK_UTIL_MAX: u128 = 990000000000000000; // 0.99e18 = 99%
    /// To calculate annual interest rates
    const SECONDS_PER_YEAR: u128 = 31_536_000;
    /// The maximum possible reserve factor set by admin
    const RESERVE_FACTOR_MAX: u128 = 200000000000000000; // 0.2e18 = 20%
    /// The max kink multiplier
    const KINK_MULTIPLIER_MAX: u128 = 40;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(
        ref self: ContractState,
        hangar18: IHangar18Dispatcher,
        underlying: ERC20ABIDispatcher,
        collateral: ICollateralDispatcher,
        oracle: ICygnusNebulaDispatcher,
        shuttle_id: u32
    ) {
        self._initialize(hangar18, underlying, collateral, oracle, shuttle_id);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusBorrow of cygnus::borrowable::interface::IBorrowable<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                          TERMINAL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IBorrowable
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn underlying(self: @ContractState) -> ContractAddress {
            self.underlying.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn collateral(self: @ContractState) -> ContractAddress {
            self.twin_star.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn nebula(self: @ContractState) -> ContractAddress {
            self.nebula.read().contract_address
        }

        /// # Implementation
        /// * IBorrowable
        fn shuttle_id(self: @ContractState) -> u32 {
            self.shuttle_id.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn total_balance(self: @ContractState) -> u128 {
            self.total_balance.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn total_assets(self: @ContractState) -> u128 {
            /// When called externally we always simulate accrual.
            self._total_assets(accrue: true)
        }

        /// # Implementation
        /// * IBorrowable
        fn exchange_rate(self: @ContractState) -> u128 {
            /// Get supply of CygUSD
            let supply = self.erc20.ERC20_total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return 1_000_000_000_000_000_000;
            }

            /// Return the exhcange rate between 1 CygLP and LP assets (ie. how much LP can be redeemed
            /// for 1 unit of CygUSD)
            return self.total_assets().div_wad(supply);
        }

        /// Transfers USDC from caller and mints them shares. Deposits all USDC into zkLend's USDC pool.
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn deposit(ref self: ContractState, assets: u128, recipient: ContractAddress) -> u128 {
            /// Locks, accrues and updates our balance
            self._lock_accrue_update();

            /// Convert underlying assets to CygUSD shares
            let mut shares = self._convert_to_shares(assets);
            assert(shares > 0, errors::CANT_MINT_ZERO);

            /// Transfer assets from caller
            let caller = get_caller_address();
            let receiver = get_contract_address();
            self.underlying.read().transferFrom(caller, receiver, assets.into());

            // Prevent inflation attack, this is only for the first depositor of the pool
            if (self.erc20.ERC20_total_supply.read() == 0) {
                shares -= 1000;
                self.erc20.mint(Zero::zero(), 1000);
            }

            /// Mint CygUSD
            self.erc20.mint(recipient, shares);

            /// Deposit USDC in strategy
            self._after_deposit(assets);

            self.emit(events::Deposit { caller, recipient, assets, shares });

            /// Unlock and update our usdc balance
            self._update_unlock();

            shares
        }

        /// Converts `shares` to USDC assets, withdraws assets from zkLend's USDC pool and sends assets to `recipient`
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn redeem(ref self: ContractState, shares: u128, recipient: ContractAddress, owner: ContractAddress) -> u128 {
            /// Locks, accrues and updates our balance
            self._lock_accrue_update();

            // Check for caller allowance
            let caller = get_caller_address();
            if caller != owner {
                self.erc20._spend_allowance(owner, caller, shares);
            }

            /// Convert to assets
            let assets = self._convert_to_assets(shares);
            assert(assets != 0, errors::CANT_REDEEM_ZERO);

            /// Withdraw from strategy
            self._before_withdraw(assets);

            // Burn CygUSD and transfer stablecoin
            self.erc20.burn(owner, shares);

            /// Transfer usd to recipient
            self.underlying.read().transfer(recipient, assets.into());

            self.emit(events::Withdraw { caller, recipient, owner, assets, shares });

            /// Unlock and update our usdc balance
            self._update_unlock();

            assets
        }

        /// Force a sync and update our total balance deposited in the strategy
        ///
        /// # Security
        /// * Non-reentrant
        ///
        /// # Implementation
        /// * IBorrowable
        fn sync(ref self: ContractState) {
            /// Locks, accrues and updates our balance
            self._lock_accrue_update();

            /// Unlock
            self.guard.write(false);
        }

        /// ---------------------------------------------------------------------------------------------------
        ///                                          3. CONTROL
        /// ---------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IBorrowable
        fn BASE_RATE_MAX(self: @ContractState) -> u128 {
            BASE_RATE_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn RESERVE_FACTOR_MAX(self: @ContractState) -> u128 {
            RESERVE_FACTOR_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_UTIL_MIN(self: @ContractState) -> u128 {
            KINK_UTIL_MIN
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_UTIL_MAX(self: @ContractState) -> u128 {
            KINK_UTIL_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn KINK_MULTIPLIER_MAX(self: @ContractState) -> u128 {
            KINK_MULTIPLIER_MAX
        }

        /// # Implementation
        /// * IBorrowable
        fn SECONDS_PER_YEAR(self: @ContractState) -> u128 {
            SECONDS_PER_YEAR
        }

        /// # Implementation
        /// * IBorrowable
        fn reserve_factor(self: @ContractState) -> u128 {
            self.reserve_factor.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn interest_rate_model(self: @ContractState) -> InterestRateModel {
            self.interest_rate_model.read()
        }

        /// # Implementation
        /// * IBorrowable
        fn pillars_of_creation(self: @ContractState) -> ContractAddress {
            self.pillars_of_creation.read()
        }

        /// Sets a new interest rate model
        ///
        /// # Security
        /// * Only-admin 👽
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_interest_rate_model(
            ref self: ContractState, base_rate: u128, multiplier: u128, kink_muliplier: u128, kink: u128
        ) {
            // Check admin
            self._check_admin();

            // Set model internally, emits event
            self._interest_rate_model(base_rate, multiplier, kink_muliplier, kink);
        }

        /// Sets a new reserve factor for the pool
        ///
        /// # Security
        /// * Only-admin 👽
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_reserve_factor(ref self: ContractState, new_reserve_factor: u128) {
            // Check sender is admin
            self._check_admin();

            /// # Error
            /// `INVALID_RANGE` - Avoid if reserve factor is above max range allowed
            assert(new_reserve_factor <= RESERVE_FACTOR_MAX, errors::INVALID_RANGE);

            // Get reserve factor until now
            let old_reserve_factor = self.reserve_factor.read();

            // Write reserve factor to storage
            self.reserve_factor.write(new_reserve_factor);

            /// # Event
            /// * `NewReserveFactor`
            self.emit(events::NewReserveFactor { old_reserve_factor, new_reserve_factor });
        }

        /// Sets the pillars of creation contract. This is allowed to be zero as we do checks for zero
        /// address in case it's inactive.
        ///
        /// # Security
        /// * Only-admin 👽
        ///
        /// # Implementation
        /// * IBorrowable
        fn set_pillars_of_creation(ref self: ContractState, new_pillars: ContractAddress) {
            // Check sender is admin
            self._check_admin();

            /// Address of CYG rewarder until now
            let old_pillars = self.pillars_of_creation.read();

            /// Write new pillars to storage
            self.pillars_of_creation.write(new_pillars);

            /// # Event
            /// * NewPillarsOfCreation
            self.emit(events::NewPillarsOfCreation { old_pillars, new_pillars });
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                          4. MODEL
        ///----------------------------------------------------------------------------------------------------

        /// Uses borrow indices
        ///
        /// # Implmentation
        /// * IBorrowable
        fn total_borrows(self: @ContractState) -> u128 {
            // Get latest borrows from indices (simulates accrual)
            let (_, total_borrows, _, _, _) = self._borrow_indices();

            total_borrows
        }

        /// Uses borrow indices
        ///
        /// # Implmentation
        /// * IBorrowable
        fn borrow_index(self: @ContractState) -> u128 {
            // Get latest index from indices
            let (_, _, index, _, _) = self._borrow_indices();

            index
        }

        /// Uses borrow indices
        ///
        /// # Implmentation
        /// * IBorrowable
        fn last_accrual_timestamp(self: @ContractState) -> u64 {
            self.last_accrual_timestamp.read()
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn utilization_rate(self: @ContractState) -> u128 {
            /// Get the latest borrow indices
            let (cash, borrows, _, _, _) = self._borrow_indices();

            /// Avoid divide by 0
            if borrows == 0 {
                return 0;
            }

            /// We do not take into account reserves as we mint CygUSD
            borrows.div_wad(cash + borrows)
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn borrow_rate(self: @ContractState) -> u128 {
            // Get the current borrows with interest
            // Calculates the borrow rate with the stored borrows and simulate interest accrual
            // up to this point.
            let (cash, borrows, _, _, _) = self._borrow_indices();

            // Calculates the latest borrow rate with the new increased borrows
            self._borrow_rate(cash, borrows)
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn supply_rate(self: @ContractState) -> u128 {
            // Get the current borrows with interest
            // Calculates the borrow rate with the stored borrows and simulate interest accrual
            // up to this point.
            let (cash, borrows, _, _, _) = self._borrow_indices();

            // Calculates the latest borrow rate with the new increased borrows
            let borrow_rate = self._borrow_rate(cash, borrows);

            /// slope = Borrow Rate * (1e18 - reserve_factor)
            let one_minus_reserves = 1_000000000_000000000 - self.reserve_factor.read();
            let rate_to_pool = borrow_rate.mul_wad(one_minus_reserves);

            /// Avoid divide by 0
            if (borrows == 0) {
                return 0;
            }

            /// Get util
            let util = borrows.div_wad(cash + borrows);

            /// Supply rate is slope * util
            util.mul_wad(rate_to_pool)
        }

        /// # Implementation
        /// * IBorrowable
        fn get_usd_price(self: @ContractState) -> u128 {
            self.nebula.read().denomination_token_price()
        }

        /// # Implementation
        /// * IBorrowable
        fn get_lender_position(self: @ContractState, lender: ContractAddress) -> (u128, u128, u128) {
            let cyg_usd_balance = self.erc20.ERC20_balances.read(lender);
            let underlying_balance = cyg_usd_balance.mul_wad(self.exchange_rate());
            let usd_balance = underlying_balance.mul_wad(self.get_usd_price());

            (cyg_usd_balance, underlying_balance, usd_balance)
        }

        /// Uses borrow indices
        ///
        /// # Implementation
        /// * IBorrowable
        fn get_borrow_balance(self: @ContractState, borrower: ContractAddress) -> (u128, u128) {
            // Simulate accrue
            self._borrow_balance(borrower, accrue: true)
        }

        /// # Implementation
        /// * IBorrowable
        fn accrue_interest(ref self: ContractState) {
            /// Accrue internally
            self._accrue();
        }

        /// # Implementation
        /// * IBorrowable
        fn track_borrower(ref self: ContractState, borrower: ContractAddress) {
            /// Borrower's receive rewards based on their principal (ie. borrowed amount) so no need to accrue
            let (principal, _) = self._borrow_balance(borrower, false);

            /// Pass balance internally, checks if pillars exists
            self._track_rewards(borrower, principal, self.twin_star.read().contract_address);
        }

        /// # Implementation
        /// * IBorrowable
        fn track_lender(ref self: ContractState, lender: ContractAddress) {
            /// Get lender's CygUSD balance
            let balance = self.balance_of(lender);

            /// Pass balance internally, checks if pillars exists
            self._track_rewards(lender, balance, Zero::zero());
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                          5. BORROWABLE
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IBorrowable
        ///
        /// # Security
        /// * Non-reentrant
        fn borrow(
            ref self: ContractState,
            borrower: ContractAddress,
            receiver: ContractAddress,
            borrow_amount: u128,
            calldata: Array<felt252>,
        ) -> u128 {
            /// Lock, accrue  and update
            self._lock_accrue_update();

            /// Check that caller has allowance to borrow on behalf of `borrower`
            /// We use the same allowance as redeem.
            let caller = get_caller_address();

            if borrower != caller {
                self.erc20._spend_allowance(borrower, caller, borrow_amount);
            }

            /// ────────── 1. Check amount and optimistically send `borrow_amount` to `receiver`
            /// We optimistically transfer borrow amounts and check in step 5 if borrower has enough 
            /// liquidity to borrow. We allow for flash loans only if repaid amount is greater than
            /// borrow amount and we skip step 5
            if borrow_amount > 0 {
                /// Withdraw from strategy
                self._before_withdraw(borrow_amount);

                /// Transfer USD to `receiver`
                self.underlying.read().transfer(receiver, borrow_amount.into());
            }

            /// Helper return val to simulate transaction or make static call to check the amount of LP
            /// received, has no meaning in the function itself.
            let mut liquidity = 0;

            /// ────────── 2. Pass data to the router if needed
            /// Check data for leverage transaction, if any pass data to router. `liquidity` is the 
            /// amount of LP received. Return var to work with a router, has no effect on this function 
            /// itself.

            /// Pass data to caller if necessary
            if calldata.len() > 0 {
                /// Get the caller address, should be any contract that subscribes to the IAltairCall interface
                let altair = IAltairDispatcher { contract_address: caller };

                /// Pass calldata to router
                liquidity = altair.altair_borrow_09E(caller, borrow_amount, calldata);
            }

            /// ────────── 3. Get the repay amount (if any)
            /// Borrow/Repay use this same function. To repay the loan the user must have sent back stablecoins 
            /// to this contract. The borrowable contract should never have any stablecoin assets itself (all is
            /// either being borrowed or deposited in zkLend), so we check for balance of stablecoin in case of repay.
            let repay_amount = self._check_balance(self.underlying.read());

            /// ────────── 4. Update borrow internally with borrowAmount and repayAmount
            /// Update internal record for `borrower` with borrow and repay amount
            let account_usd = self._update_borrow(borrower, borrow_amount, repay_amount);

            /// ────────── 5. Do checks for borrow and repay transactions
            /// Borrow transaction. Check that the borrower has sufficient collateral after borrowing 
            /// `borrowAmount` by passing `accountBorrows` to the collateral contract
            if borrow_amount > repay_amount {
                /// The collateral contract prices the user's deposited liquidity in USD. If the borrowed
                /// amount (+ current borrow balance) would put the user in shortfall then it returns false
                let can_borrow: bool = self.twin_star.read().can_borrow(borrower, account_usd);

                /// # Error
                /// * `INSUFFICIENT_LIQUIDITY` - Revert if user has insufficient collateral amount for this loan
                assert(can_borrow, errors::INSUFFICIENT_LIQUIDITY);
            }

            /// ────────── 6. Deposit in strategy
            /// Deposit underlying in strategy (only from repay transaction)
            if repay_amount > 0 {
                self._after_deposit(repay_amount);
            };

            /// # Event
            /// * `Borrow`
            self.emit(events::Borrow { caller, borrower, receiver, borrow_amount, repay_amount });

            /// Unlock
            self._update_unlock();

            liquidity
        }

        /// # Implementation
        /// * IBorrowable
        ///
        /// # Security
        /// * Non-reentrant
        fn liquidate(
            ref self: ContractState,
            borrower: ContractAddress,
            receiver: ContractAddress,
            repay_amount: u128,
            calldata: Array<felt252>
        ) -> u128 {
            /// Lock, accrue  and update
            self._lock_accrue_update();

            /// Get the sender address - We need this for the router to allow flash liquidations
            let caller = get_caller_address();

            /// ────────── 1. Get borrower's latest USD debt - `update` accrued interest before this call
            /// Latest borrow balance - We have already accured so its guaranteed to be the latest balance
            let (_, borrow_balance) = self._borrow_balance(borrower, accrue: false);

            /// Make sure that the amount being repaid is never more than the borrower's borrow balance
            let max = if repay_amount > borrow_balance {
                borrow_balance
            } else {
                repay_amount
            };

            /// ────────── 2. Seize CygLP from borrower
            /// CygLP = (max * liq. incentive) / lp price.
            /// Reverts at Collateral if:
            /// - `max` is 0.
            /// - `borrower`'s position is not in liquidatable state
            let cyg_lp_amount = self.twin_star.read().seize_cyg_lp(receiver, borrower, max);

            /// ────────── 3. Check for data length in case sender sells the collateral to market
            /// If the `receiver` was the router used to flash liquidate then we call the router 
            /// with the data passed, allowing the collateral to be sold to the market
            /// Pass data to caller if necessary
            if calldata.len() > 0 {
                /// Get the caller address, should be any contract that subscribes to the IAltairCall interface
                let altair = IAltairDispatcher { contract_address: caller };

                /// Pass calldata to router
                altair.altair_liquidate_f2x(caller, cyg_lp_amount, max, calldata);
            }

            /// ────────── 4. Get the repaid amount of USD
            /// Our balance of USD not deposited in strategy (if sell to market then router must 
            /// have sent back USD).
            /// The amount received back would have to be equal at least to `max`, allowing liquidator to 
            /// keep the liquidation incentive
            let amount_usd = self._check_balance(self.underlying.read());

            /// # Error
            /// * `INSUFFICIENT_USD_RECEIVED` - Reverts if we received less USD than declared
            assert(amount_usd >= max, errors::INSUFFICIENT_USD_RECEIVED);

            /// ────────── 5. Update borrow internally with 0 borrow amount and the amount of usd received
            /// Pass to CygnusBorrowModel
            self._update_borrow(borrower, 0, amount_usd);

            /// ────────── 6. Deposit in strategy
            /// Deposit underlying in strategy, if 0 then would've reverted by now
            self._after_deposit(repay_amount);

            /// # Event
            /// * `Liquidate`
            self.emit(events::Liquidate { caller, borrower, receiver, cyg_lp_amount, max, amount_usd });

            /// Unlock
            self._update_unlock();

            amount_usd
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// Constructor logic
    /// 1. Set immutable variables
    /// 2. Set default borrowable control parameters
    /// 3. Set strategy
    #[generate_trait]
    impl ConstructorImpl of ConstructorTrait {
        fn _initialize(
            ref self: ContractState,
            hangar18: IHangar18Dispatcher,
            underlying: ERC20ABIDispatcher,
            collateral: ICollateralDispatcher,
            oracle: ICygnusNebulaDispatcher,
            shuttle_id: u32
        ) {
            /// The factory used as control centre
            self.hangar18.write(hangar18);

            /// The underlying stablecoin address
            self.underlying.write(underlying);

            /// The collateral address
            self.twin_star.write(collateral);

            /// The oracle used to price the LP
            self.nebula.write(oracle);

            /// The lending pool ID
            self.shuttle_id.write(shuttle_id);

            /// Borrowable defaults
            self._set_default_borrowable();
        }

        /// Sets the default borrowable values (reserve rate, interest rate, etc.)
        /// Called only in the constructor
        fn _set_default_borrowable(ref self: ContractState) {
            // Store the default borrow index as 1 and the current timestamp 
            self.borrow_index.write(1_000_000_000_000_000_000);
            self.last_accrual_timestamp.write(get_block_timestamp());
            self.reserve_factor.write(200000000000000000); // 0.20e18 = 20%

            /// Initialize borrowable strategy, in this case we use zkLend
            self._initialize_void();
        }

        /// Initialize Strategy
        fn _initialize_void(ref self: ContractState) {
            /// The ZKLend Market contract, which allows users to deposit/withdraw from the markets.
            let zk_lend_market = IZKLendMarketDispatcher {
                contract_address: starknet::contract_address_const::<
                    0x04c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05
                >()
            };

            /// We approve the zkmarket contract to move our USDC
            /// As soon as users deposit into Cygnus / we deposit the USDC into zkLend through the Market contract, 
            /// so it must have allowance / to move our USDC.
            self.underlying.read().approve(zk_lend_market.contract_address.into(), BoundedInt::max());

            /// This is the zk token that represents our deposits in the market. It is a rebase token that
            /// is received by the vault when we deposit USDC. IMPORTANT: We must disallow admin to move
            /// this token when sweeping incorrect erc20 transfers to this contract, or else malicious admin
            /// can have control of the vault!
            let zk_lend_usdc = ERC20ABIDispatcher {
                contract_address: starknet::contract_address_const::<
                    0x047ad51726d891f972e74e4ad858a261b43869f7126ce7436ee0b2529a98f486
                >()
            };

            /// Write the market to storage
            self.zk_lend_market.write(zk_lend_market);

            /// Write zUSDC share token to storage
            self.zk_lend_usdc.write(zk_lend_usdc);
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - TERMINAL
    ///----------------------------------------------------------------------------------------------------

    /// Internal logic that handles the terminal vault token (CygUSD)
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

        /// Gets the total assets owned by the borrowable vault, ie. total cash + total borrows
        /// 
        /// # Arguments
        /// * `accrue` - Whether we should simulate accrual or not, gas savings
        ///
        /// # Returns
        /// * The total cash deposited in the strategy + the total borrows stored
        fn _total_assets(self: @ContractState, accrue: bool) -> u128 {
            /// Check if we should simulate accrual using indices, avoid when called internally
            if (accrue) {
                /// Total cash
                let balance = self._preview_total_balance();
                /// Latest borrows with interest accrued
                let (_, borrows, _, _, _) = self._borrow_indices();

                return balance + borrows;
            }

            /// Read directly from storage
            self.total_balance.read() + self.total_borrows.read()
        }

        /// Convert CygUSD shares to USD assets
        ///
        /// # Arguments
        /// * `shares` - The amount of CygUSD shares to convert to USD
        ///
        /// # Returns
        /// * The assets equivalent of shares
        #[inline(always)]
        fn _convert_to_assets(self: @ContractState, shares: u128) -> u128 {
            // Gas savings
            let supply = self.erc20.ERC20_total_supply.read();

            // If no supply return shares 
            if supply == 0 {
                return shares;
            }

            // We have already accrued interest since we use `lock_and_update`
            // in redeem, so pass false to avoid loading indicies again and save gas
            // assets = shares * balance / total supply
            shares.full_mul_div(self._total_assets(accrue: false), supply)
        }

        /// Convert USD assets to CygUSD shares - We have already accrued interest
        ///
        /// # Arguments
        /// * `assets` - The amount of USD assets to convert to CygUSD shares
        ///
        /// # Returns
        /// * The shares equivalent of assets
        #[inline(always)]
        fn _convert_to_shares(self: @ContractState, assets: u128) -> u128 {
            // Gas savings
            let supply = self.erc20.ERC20_total_supply.read();

            // If no supply return assets
            if supply == 0 {
                return assets;
            }

            // We have already accrued interest since we use `lock_and_update`
            // in deposit, so pass false to avoid loading indicies again and save gas
            // shares = assets * supply / balance
            assets.full_mul_div(supply, self._total_assets(accrue: false))
        }

        /// Syncs the `total_balance` variable with the currently deposited cash in the strategy.
        /// This should be called after any payable action, and before to prevent deposit spams into
        /// the vault.
        #[inline(always)]
        fn _update(ref self: ContractState) {
            /// Get our cash currently deposited in the strategy
            let balance = self._preview_total_balance();

            /// Update cash to storage
            self.total_balance.write(balance);

            /// # Event
            /// * `SyncBalance`
            self.emit(events::SyncBalance { balance });
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - CONTROL
    ///----------------------------------------------------------------------------------------------------

    /// Control
    #[generate_trait]
    impl ControlImpl of ControlTrait {
        /// Updates the interest rate model internally
        ///
        /// # Arguments
        /// * `base_rate` - The annualized base rate
        /// * `multiplier` - The annualized multiplier
        /// * `kink_multiplier` - The kink multiplier
        /// * `kink` - The point at which the borrow rate goes steep
        fn _interest_rate_model(
            ref self: ContractState, base_rate: u128, multiplier: u128, kink_muliplier: u128, kink: u128
        ) {
            /// # Error
            /// * `INVALID_RANGE` - Avoid if not within range
            assert(base_rate < BASE_RATE_MAX, errors::INVALID_RANGE);
            assert(kink >= KINK_UTIL_MIN && kink <= KINK_UTIL_MAX, errors::INVALID_RANGE);
            assert(kink_muliplier <= KINK_MULTIPLIER_MAX, errors::INVALID_RANGE);

            // The annualized slope of the interest rate
            let slope = multiplier.div_wad(SECONDS_PER_YEAR * kink);

            // Create interest rate model struct
            let interest_rate_model: InterestRateModel = InterestRateModel {
                base_rate_per_second: (base_rate / SECONDS_PER_YEAR).try_into().unwrap(),
                multiplier_per_second: slope.try_into().unwrap(),
                jump_multiplier_per_second: (slope * kink_muliplier).try_into().unwrap(),
                kink: kink.try_into().unwrap()
            };

            // Write to storage
            self.interest_rate_model.write(interest_rate_model);

            /// # Event
            /// * `NewInterestRateModel`
            self.emit(events::NewInterestRateModel { base_rate, multiplier, kink_muliplier, kink });
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - MODEL
    ///----------------------------------------------------------------------------------------------------

    /// CygnusBorrowModel
    ///
    /// Logic for borrowable model
    #[generate_trait]
    impl ModelImpl of ModelTrait {
        /// Calculates the utilization rate of the pool
        ///
        /// # Arguments
        /// * `cash` - Total cash deposited in the strategy
        /// * `borrows` - Total current borrows from the pool
        ///
        /// # Returns
        /// * The utilization rate of the pool (ie. borrows / (cash + borrows))
        fn _utilization_rate(self: @ContractState, cash: u128, borrows: u128) -> u128 {
            // Avoid divide by 0
            if borrows.is_zero() {
                return 0;
            }

            borrows.div_wad(cash + borrows)
        }

        /// Mints reserves interally if reserve rate is set
        ///
        /// # Arguments
        /// * `interest_accumulated` - The amount of interest accumulated since last accrual
        ///
        /// # Returns
        /// * The amount of shares minted to the DAO Reserves
        fn _mint_reserves(ref self: ContractState, cash: u128, borrows: u128, interest: u128) -> u128 {
            /// Get the reserves (interest accrued * reserve factor)
            let new_reserves = interest.mul_wad(self.reserve_factor.read());

            /// Since we mint CygUSD shares for reserves we use the same calculation as
            /// `convert_to_shares` but use the cash and borrows from the borrow_indices for gas savings
            if (new_reserves > 0) {
                let supply = self.erc20.ERC20_total_supply.read();
                let cyg_usd_amount = new_reserves.full_mul_div(supply, (cash + borrows - new_reserves));
                let dao_reserves = self.hangar18.read().dao_reserves();
                self.erc20.mint(dao_reserves, cyg_usd_amount);
            }

            new_reserves
        }

        /// Accrues interest to total borrows and as a result increases `total_borrows`,
        /// `borrow_index` and `last_accrual_timestamp`
        fn _accrue(ref self: ContractState) {
            /// Accrue interest internally
            let (cash, borrows, index, time_elapsed, interest) = self._borrow_indices();

            /// If the timestamp is last accrual then escape
            if (time_elapsed == 0) {
                return;
            }

            // Check for reserves and mint if necessary before updating total_borrows
            let new_reserves = self._mint_reserves(cash, borrows, interest);

            /// Update storage
            self.total_borrows.write(borrows);
            self.borrow_index.write(index);
            self.last_accrual_timestamp.write(get_block_timestamp());

            /// # Emit
            /// * `AccrueInterest`
            self.emit(events::AccrueInterest { cash, borrows, interest, new_reserves });
        }

        /// Gets the latest borrow indices to calculate the up to date total borrows and borrow index
        ///
        /// # Returns
        /// * The current available cash (ie `total_balance`)
        /// * The latest total pool borrows (with interest accrued)
        /// * The latest borrow index
        /// * The time elapsed since last accrual
        /// * The interest accumulated since last accrual
        fn _borrow_indices(self: @ContractState) -> (u128, u128, u128, u64, u128) {
            /// 1. Get available cash, total borrows and current borrow index stored
            let cash = self.total_balance.read();
            let mut total_borrows = self.total_borrows.read();
            let mut borrow_index = self.borrow_index.read();

            /// 2. Get timestamp and check time elapsed since last interest accrual
            let time_elapsed = get_block_timestamp() - self.last_accrual_timestamp.read();

            if time_elapsed == 0 {
                return (cash, total_borrows, borrow_index, 0, 0);
            }

            /// 3. Calculate the latest borrow rate and calculate interest accumulated
            let borrow_rate = self._borrow_rate(cash, total_borrows);
            let interest_factor = borrow_rate * time_elapsed.into();
            let interest_accumulated = interest_factor.mul_wad(total_borrows);

            /// 4. Calculate latest total borrows and borrow index in this pool
            total_borrows += interest_accumulated;
            borrow_index += interest_factor.mul_wad(borrow_index);

            (cash, total_borrows, borrow_index, time_elapsed, interest_accumulated)
        }

        /// Gets the borrow balance of a user from the snapshot
        ///
        /// # Arguments
        /// * `borrower` - The address of the borrower
        /// * `accrue` - Whether we should simulate accrual or not (gas savings)
        ///
        /// # Returns
        /// * The borrower's principal (actual borrowed amount)
        /// * The borrowed amount with interest
        fn _borrow_balance(self: @ContractState, borrower: ContractAddress, accrue: bool) -> (u128, u128) {
            // Load borrower snapshot
            let snapshot: BorrowSnapshot = self.borrow_balances.read(borrower);

            // If user interest index is 0 then borrows is 0
            if snapshot.interest_index == 0 {
                return (0, 0);
            }

            /// Get latest index
            let mut index = self.borrow_index.read();

            /// If accrue then get indices
            if accrue {
                /// Simulate accrual and get latest borrow index
                let (_, _, new_index, _, _) = self._borrow_indices();

                index = new_index;
            }

            // The borrow balance (ie what the borrower owes with interest) is:
            // (borrower.principal * borrow_index) / borrower.interest_index
            let borrow_balance = snapshot.principal.full_mul_div(index, snapshot.interest_index);

            (snapshot.principal, borrow_balance)
        }

        /// Internal function to calculate the latest borrow rate per second
        ///
        /// # Arguments
        /// Caclulate borrow rate internally
        fn _borrow_rate(self: @ContractState, cash: u128, borrows: u128) -> u128 {
            // Real model stored vars
            let model: InterestRateModel = self.interest_rate_model.read();

            // If borrows is 0, util is 0, return base rate per second
            if (borrows == 0) {
                return model.base_rate_per_second.into();
            }

            // Else return slope
            let util = borrows.div_wad(cash + borrows);

            // Under kink
            if (util <= model.kink.into()) {
                let slope = util.mul_wad(model.multiplier_per_second.into());
                let base_rate = model.base_rate_per_second;
                return slope + base_rate.into();
            }

            // Over kink
            let max_slope = model.kink.into().mul_wad(model.multiplier_per_second.into());
            let base_rate = model.base_rate_per_second;
            let normal_rate = max_slope + base_rate.into();
            let excess_util = util - model.kink.into();

            // normal_rate + excess_util * jump_multiplier
            excess_util.mul_wad(model.jump_multiplier_per_second.into()) + normal_rate
        }

        /// Updates the borrow snapshot after any borrow, repay or liquidation
        ///
        /// # Arguments
        /// * `borrower` - The address of the borrower
        /// * `borrow_amount` - The borrowed amount (can be 0)
        /// * `repay_amount` - The repaid amount (can be 0)
        ///
        /// # Returns
        /// * The total account borrows after the update
        fn _update_borrow(
            ref self: ContractState, borrower: ContractAddress, borrow_amount: u128, repay_amount: u128
        ) -> u128 {
            // Load snapshot - We have already accrued since this function is only called
            // after `borrow()` or `liquidate()` which accrue beforehand
            let (_, borrow_balance) = self._borrow_balance(borrower, accrue: false);

            // In case of flash loan or 0 return current borrow_balance
            if (borrow_amount == repay_amount) {
                return borrow_balance;
            }

            // Read borrow index to adjust
            let borrow_index = self.borrow_index.read();

            // Get snapshot for borrower
            let mut snapshot: BorrowSnapshot = self.borrow_balances.read(borrower);

            /// The return var. Keeps track of the user's account current borrows and pass
            /// it to the rewarder to track rewards
            let mut account_borrows = 0;

            // Borrow transaction
            if (borrow_amount > repay_amount) {
                /// Increase borrower's borrow balance by new borrow amount
                let increase_borrow_amount = borrow_amount - repay_amount;
                account_borrows = borrow_balance + increase_borrow_amount;

                /// Update snapshot
                snapshot.principal = account_borrows;
                snapshot.interest_index = borrow_index;
                self.borrow_balances.write(borrower, snapshot);

                /// Increase total pool borrows
                let total_borrows = self.total_borrows.read() + increase_borrow_amount;
                self.total_borrows.write(total_borrows);
            } else {
                /// Decrease borrower's borrow balance by repaid amount
                let decrease_borrow_amount = repay_amount - borrow_amount;
                account_borrows =
                    if borrow_balance > decrease_borrow_amount {
                        borrow_balance - decrease_borrow_amount
                    } else {
                        0
                    };

                /// Update snapshot
                snapshot.principal = account_borrows;
                snapshot.interest_index = if account_borrows == 0 {
                    0
                } else {
                    borrow_index
                };
                self.borrow_balances.write(borrower, snapshot);

                /// Decrease total pool borrows
                let actual_decrease_amount = borrow_balance - account_borrows;
                let mut total_borrows = self.total_borrows.read();
                total_borrows =
                    if total_borrows > actual_decrease_amount {
                        total_borrows - actual_decrease_amount
                    } else {
                        0
                    };

                self.total_borrows.write(total_borrows);
            }

            /// Track rewards
            self._track_rewards(borrower, account_borrows, self.twin_star.read().contract_address);

            /// Return the total account borrows after update
            account_borrows
        }

        /// Tracks CYG rewards internally for borrowers and lenders
        ///
        /// # Arguments
        /// * `account` - Address of the borrower or lender
        /// * `balance` - Balance of CygUSD for lenders, the USDC borrow balance for borrowers
        /// * `collateral` - The address of the collateral. For lenders, this is always the zero address
        fn _track_rewards(
            ref self: ContractState, account: ContractAddress, balance: u128, collateral: ContractAddress
        ) {
            /// Get current pillars
            let pillars = self.pillars_of_creation.read();

            /// If it is not set then escape
            if pillars.is_zero() {
                return;
            }
        /// Pass lender or borrower info to the rewarder TODO
        //pillars.track_rewards(account, balance, collateral);
        }
    }

    ///----------------------------------------------------------------------------------------------------
    ///                                          LOGIC - STRATEGY
    ///----------------------------------------------------------------------------------------------------

    /// CygnusBorrowableVoid
    ///
    /// Internal logic that handles the strategy for the underlying
    #[generate_trait]
    impl VoidImpl of VoidTrait {
        /// Preview our total balance deposited in the strategy.
        /// This is a helper function that is used only when syncing our balance with the `_update` function.
        #[inline(always)]
        fn _preview_total_balance(self: @ContractState) -> u128 {
            /// zkUSDC rebases on each interest accrual, so our underlying balance is our zkUSDC balance
            self.zk_lend_usdc.read().balanceOf(get_contract_address()).try_into().unwrap()
        }

        /// Hook that handles underlying deposits into the strategy
        ///
        /// # Arguments
        /// * `amount` - The amount of underlying stablecoin to deposit into the strategy
        #[inline(always)]
        fn _after_deposit(ref self: ContractState, amount: u128) {
            /// Get the zkLend market from storage
            let zk_lend_market = self.zk_lend_market.read();

            /// Deposit `amount` of stablecoin into market
            zk_lend_market.deposit(self.underlying.read().contract_address, amount.try_into().unwrap());
        }


        /// Hook that handles underlying withdrawals from the strategy
        ///
        /// # Arguments
        /// * `amount` - The amount of underlying stablecoin to withdraw from the zkLend market
        #[inline(always)]
        fn _before_withdraw(ref self: ContractState, amount: u128) {
            /// Get the zkLend market from storage
            let market = self.zk_lend_market.read();

            /// Withdraw `amount` of stablecoin from zklend market
            market.withdraw(self.underlying.read().contract_address, amount.try_into().unwrap());
        }
    }

    /// Utils
    #[generate_trait]
    impl UtilsImpl of UtilsTrait {
        /// It locks and accrues interest. After accrual we update the total_balance var to sync 
        /// our underlying balance with the strategy
        #[inline(always)]
        fn _lock_accrue_update(ref self: ContractState) {
            /// # Error
            /// * `REENTRANT_CALL` - Reverts if already entered
            assert(!self.guard.read(), errors::REENTRANT_CALL);

            /// Lock
            self.guard.write(true);

            /// Accrue interest
            self._accrue();

            /// Update total balance in terms of underlying
            self._update();
        }

        /// Unlock and update our total_balance var after any payable action
        #[inline(always)]
        fn _update_unlock(ref self: ContractState) {
            /// Update after action
            self._update();

            /// Unlock
            self.guard.write(false);
        }

        /// Get the balance of USDC currently in this contract
        /// The vault should never have USDC unless when repaying and depositing,
        /// and it then gets deposited in the strategy
        fn _check_balance(self: @ContractState, token: ERC20ABIDispatcher) -> u128 {
            token.balanceOf(get_contract_address()).try_into().unwrap()
        }
    }
}

