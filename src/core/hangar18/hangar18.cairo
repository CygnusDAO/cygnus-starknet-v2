//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  Hangar18.sol
//
//  Copyright (C) 2024 CygnusDAO
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════  .
//  .               .            .               .      🛰️     .           .                 *              .
//         █████████           ---======*.                                                 .           ⠀
//        ███░░░░░███                                               📡                🌔                       . 
//       ███     ░░░  █████ ████  ███████ ████████   █████ ████  █████        ⠀
//      ░███         ░░███ ░███  ███░░███░░███░░███ ░░███ ░███  ███░░      .     .⠀           .           .
//      ░███          ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███ ░░█████       ⠀
//      ░░███     ███ ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███  ░░░░███              .             .⠀
//       ░░█████████  ░░███████ ░░███████ ████ █████ ░░████████ ██████     .----===*  ⠀
//        ░░░░░░░░░    ░░░░░███  ░░░░░███░░░░ ░░░░░   ░░░░░░░░ ░░░░░░            .                            .⠀
//                     ███ ░███  ███ ░███                .                 .                 .  ⠀
//   🛰️  .             ░░██████  ░░██████                                             .                 .           
//                     ░░░░░░    ░░░░░░      -------=========*                      .                     ⠀
//         .                            .       .          .            .                          .             .⠀
//  
//      LENDING POOL FACTORY V1 - `Hangar18`                                                           
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════  

//! # Hangar18
//!
//! Factory-like contract for CygnusDAO which deploys all borrow/collateral contracts in this chain. There
//! is only 1 factory contract per chain along with multiple pairs of `orbiters`.
//!
//! Orbiters are the collateral and borrow deployer contracts which are not part of the core contracts, 
//! but instead are in charge of deploying the arms of core contracts with each other's addresses 
//! (borrow orbiter deploys the borrow arm with the collateral address, and vice versa).
//!
//! Orbiters = Strategies for the underlying assets.
#[starknet::contract]
pub mod Hangar18 {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// Cygnus Core
    use core::num::traits::Zero;
    use cygnus::core::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::core::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::core::hangar18::{errors, events};
    use cygnus::core::orbiters::albireo::{IAlbireoDispatcher, IAlbireoDispatcherTrait};
    use cygnus::core::orbiters::deneb::{IDenebDispatcher, IDenebDispatcherTrait};

    // DAO 
    use cygnus::dao::reserves::{ICygnusDAOReservesDispatcher, ICygnusDAOReservesDispatcherTrait};
    use cygnus::nebula::{ICygnusNebulaDispatcher, ICygnusNebulaDispatcherTrait};
    use cygnus::types::ekubo::{PoolKeyCYG};
    use cygnus::types::orbiter::{Orbiter};
    use cygnus::types::shuttle::{Shuttle};
    use cygnus::utils::addresses::{ETH, USDC};
    use cygnus::utils::math::MathLib::MathLibTrait;

    use starknet::{ContractAddress, get_tx_info, get_block_timestamp, get_caller_address};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewAdmin: events::NewAdmin,
        NewPendingAdmin: events::NewPendingAdmin,
        NewOrbiter: events::NewOrbiter,
        NewShuttle: events::NewShuttle,
        NewDAOReserves: events::NewDAOReserves,
        SwitchOrbiterStatus: events::SwitchOrbiterStatus,
        NewCygnusAltair: events::NewCygnusAltair,
        NewCygnusX1Vault: events::NewCygnusX1Vault,
        NewCygnusPillars: events::NewCygnusPillars
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        admin: ContractAddress,
        pending_admin: ContractAddress,
        nebula: ICygnusNebulaDispatcher,
        dao_reserves: ICygnusDAOReservesDispatcher,
        total_orbiters: u32,
        total_shuttles: u32,
        all_orbiters: LegacyMap::<u32, Orbiter>,
        all_shuttles: LegacyMap::<u32, Shuttle>,
        usd: ContractAddress,
        native_token: ContractAddress,
        cygnus_x1_vault: ContractAddress,
        cygnus_altair: ContractAddress,
        cygnus_pillars: ContractAddress
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress, nebula: ICygnusNebulaDispatcher) {
        // Admin and registry
        self.admin.write(admin);
        self.nebula.write(nebula);

        // Address of native (ie ETH)
        self.native_token.write(ETH.try_into().unwrap());

        // Address of USDC on Starknet
        self.usd.write(USDC.try_into().unwrap());
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl Hangar18Impl of cygnus::core::hangar18::IHangar18<ContractState> {
        ///----------------------------------------------------------------------------------------------------
        ///                                        CONSTANT FUNCTIONS
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * IHangar18
        fn name(self: @ContractState) -> ByteArray {
            "Hangar18"
        }

        /// # Implementation
        /// * IHangar18
        fn version(self: @ContractState) -> ByteArray {
            "1.0.0"
        }

        /// # Implementation
        /// * IHangar18
        fn admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        /// # Implementation
        /// * IHangar18
        fn pending_admin(self: @ContractState) -> ContractAddress {
            self.pending_admin.read()
        }

        /// # Implementation
        /// * IHangar18
        fn nebula_registry(self: @ContractState) -> ContractAddress {
            self.nebula.read().contract_address
        }

        /// # Implementation
        /// * IHangar18
        fn dao_reserves(self: @ContractState) -> ContractAddress {
            self.dao_reserves.read().contract_address
        }

        /// # Implementation
        /// * IHangar18
        fn usd(self: @ContractState) -> ContractAddress {
            self.usd.read()
        }

        /// # Implementation
        /// * IHangar18
        fn native_token(self: @ContractState) -> ContractAddress {
            self.native_token.read()
        }

        /// # Implementation
        /// * IHangar18
        fn chain_id(self: @ContractState) -> felt252 {
            get_tx_info().unbox().chain_id
        }

        /// # Implementation
        /// * IHangar18
        fn cygnus_x1_vault(self: @ContractState) -> ContractAddress {
            self.cygnus_x1_vault.read()
        }

        /// # Implementation
        /// * IHangar18
        fn cygnus_pillars(self: @ContractState) -> ContractAddress {
            self.cygnus_pillars.read()
        }

        /// # Implementation
        /// * IHangar18
        fn cygnus_altair(self: @ContractState) -> ContractAddress {
            self.cygnus_altair.read()
        }

        /// # Implementation
        /// * IHangar18
        fn all_orbiters(self: @ContractState, id: u32) -> Orbiter {
            let orbiter: Orbiter = self.all_orbiters.read(id);
            orbiter
        }

        /// # Implementation
        /// * IHangar18
        fn all_shuttles(self: @ContractState, id: u32) -> Shuttle {
            let shuttle: Shuttle = self.all_shuttles.read(id);
            shuttle
        }

        /// # Implementation
        /// * IHangar18
        fn orbiters_deployed(self: @ContractState) -> u32 {
            self.total_orbiters.read()
        }

        /// # Implementation
        /// * IHangar18
        fn shuttles_deployed(self: @ContractState) -> u32 {
            self.total_shuttles.read()
        }

        /// ------ These are functions for reporting purposes only -------

        /// # Implementation
        /// * IHangar18
        fn borrowable_tvl_usd(self: @ContractState, shuttle_id: u32) -> u128 {
            /// Borrowable contract of this shuttle
            let borrowable = self.all_shuttles.read(shuttle_id).borrowable;

            /// Total assets is USDC deposited in strategy + current USDC borrows
            let total_assets = borrowable.total_assets();

            /// Get the price of the USDC in 18 decimals
            let usd_price = borrowable.get_usd_price();

            total_assets.mul_wad(usd_price)
        }

        /// # Implementation
        /// * IHangar18
        fn collateral_tvl_usd(self: @ContractState, shuttle_id: u32) -> u128 {
            /// Collateral contract of this shuttle
            let collateral = self.all_shuttles.read(shuttle_id).collateral;

            /// Total assets is LP Tokens deposited in the vault
            let total_assets = collateral.total_assets();

            /// Get the price of 1 LP denominated in USDC decimals
            let lp_token_price = collateral.get_lp_token_price();

            total_assets.mul_wad(lp_token_price)
        }

        /// # Implementation
        /// * IHangar18
        fn shuttle_tvl_usd(self: @ContractState, shuttle_id: u32) -> u128 {
            /// Borrowable TVL + Collateral TVL
            self.borrowable_tvl_usd(shuttle_id) + self.collateral_tvl_usd(shuttle_id)
        }

        /// # Implementation
        /// * IHangar18
        fn all_borrowables_tvl(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and tvl accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut length = 0;
            let mut tvl = 0;

            /// Loop through all borrowables and accumulate TVL
            loop {
                if length == total_shuttles {
                    break;
                }
                tvl += self.borrowable_tvl_usd(length);
                length += 1;
            };

            tvl
        }

        /// # Implementation
        /// * IHangar18
        fn all_collaterals_tvl(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and tvl accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut length = 0;
            let mut tvl = 0;

            /// Loop through all collaterals and accumulate TVL
            loop {
                if length == total_shuttles {
                    break;
                }
                tvl += self.collateral_tvl_usd(length);
                length += 1;
            };

            tvl
        }

        /// # Implementation
        /// * IHangar18
        fn cygnus_tvl_usd(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and tvl accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut length = 0;
            let mut tvl = 0;

            /// Loop through all shuttles and accumulate tvl
            loop {
                /// Break clause
                if length == total_shuttles {
                    break;
                }

                /// Add to TVL
                tvl += self.shuttle_tvl_usd(length);

                /// Increase length
                length += 1;
            };

            tvl
        }

        /// # Implementation
        /// * IHangar18
        fn cygnus_total_borrows_usd(self: @ContractState) -> u128 {
            /// Get total shuttles and initialize length and borrows accumulator
            let total_shuttles = self.total_shuttles.read();
            let mut borrows = 0;
            let mut length = 0;

            /// Loop through all shuttles and accumulate borrows
            loop {
                /// Break clause
                if length == total_shuttles {
                    break;
                }

                /// Get shuttle ID
                let shuttle: Shuttle = self.all_shuttles.read(length);

                /// Get current borrows from the borrowable
                let total_borrows = shuttle.borrowable.total_borrows();

                /// Add to borrows
                borrows += total_borrows;

                /// Increase length
                length += 1;
            };

            borrows
        }

        ///----------------------------------------------------------------------------------------------------
        ///                                     NON-CONSTANT FUNCTIONS
        ///----------------------------------------------------------------------------------------------------

        /// Initializes a new orbiter in the factory and assigns it a unique ID
        ///
        /// # Implementation 
        /// * IHangar18
        fn set_orbiter(
            ref self: ContractState, name: felt252, albireo_orbiter: IAlbireoDispatcher, deneb_orbiter: IDenebDispatcher
        ) {
            // Total orbiters deployed
            let orbiter_id = self.total_orbiters.read();

            // Build orbiter and assign unique ID
            let orbiter: Orbiter = Orbiter { status: true, orbiter_id, albireo_orbiter, deneb_orbiter, name };

            // Store orbiter struct
            self.all_orbiters.write(orbiter_id, orbiter);

            // Increase ID
            self.total_orbiters.write(orbiter_id + 1);

            /// # Event
            /// * `NewOrbiter`
            self.emit(events::NewOrbiter { orbiter_id, albireo_orbiter, deneb_orbiter });
        }

        /// Reverts future deployments with disabled orbiter
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn switch_orbiter_status(ref self: ContractState, orbiter_id: u32) {
            // Check for admin
            self._check_admin();

            // Total orbiters deployed
            let mut orbiter: Orbiter = self.all_orbiters.read(orbiter_id);

            /// Switch on/off
            orbiter.status = !orbiter.status;

            /// Update orbiter storage
            self.all_orbiters.write(orbiter_id, orbiter);

            /// # Event
            /// * `SwitchOrbiterStatus`
            self.emit(events::SwitchOrbiterStatus { orbiter_id, status: orbiter.status })
        }

        /// Deploys a lending pool, given an LP Token Pair and the ID for the deployers
        ///
        /// # Implementation
        /// * IHangar18
        fn deploy_shuttle(
            ref self: ContractState, orbiter_id: u32, pool_key: PoolKeyCYG
        ) -> (IBorrowableDispatcher, ICollateralDispatcher) {
            // 1. Load orbiter
            let orbiter: Orbiter = self.all_orbiters.read(orbiter_id);

            /// # Error
            /// * `ORBITER_INACTIVE` - Revert if orbiter is switched off
            assert(orbiter.status, errors::ORBITER_INACTIVE);

            // 2: Assign unique shuttle id
            let shuttle_id: u32 = self.total_shuttles.read();

            // 3. Get Oracle
            // Check the registry for the oracle for this LP
            let nebula: ICygnusNebulaDispatcher = self.nebula.read();
            let initialized: bool = nebula.nebula_oracle(pool_key).initialized;

            /// # Error
            /// * `ORACLE_NOT_INITIALIZED`
            assert(!initialized, errors::ORACLE_NOT_INITIALIZED);

            /// 4. Deploy lending pool
            /// Use collateral orbiter to deploy lp token pool, deploy with borrowable as zero address
            let collateral: ICollateralDispatcher = orbiter
                .deneb_orbiter
                .deploy_collateral(
                    pool_key,
                    IBorrowableDispatcher { contract_address: Zero::zero() },
                    nebula.contract_address,
                    shuttle_id
                );

            /// Use borrowable orbiter to deploy stablecoin pool with deployed collateral address
            let borrowable: IBorrowableDispatcher = orbiter
                .albireo_orbiter
                .deploy_borrowable(self.usd.read(), collateral, nebula.contract_address, shuttle_id);

            // Set the borrowable in collateral
            collateral.set_borrowable(borrowable);

            // 5. Write to storage
            let shuttle: Shuttle = Shuttle {
                deployed: true,
                shuttle_id: shuttle_id,
                borrowable: borrowable,
                collateral: collateral,
                orbiter_id: orbiter_id
            };

            // Write shuttle to array
            self.all_shuttles.write(shuttle_id, shuttle);

            // Increase unique shuttle id's
            self.total_shuttles.write(shuttle_id + 1);

            // Emit `NewShuttle` event
            self.emit(events::NewShuttle { shuttle_id, borrowable, collateral });

            // Return borrowable and collateral deployed
            (borrowable, collateral)
        }

        /// Sets a new pending admin which they must then accept ownership
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn set_pending_admin(ref self: ContractState, new_pending_admin: ContractAddress) {
            /// Check sender is admin
            self._check_admin();

            /// Pending admin up until now
            let old_pending_admin: ContractAddress = self.pending_admin.read();

            /// Store new pending admin
            self.pending_admin.write(new_pending_admin);

            /// # Event
            /// * `NewPendingAdmin`
            self.emit(events::NewPendingAdmin { old_pending_admin, new_pending_admin });
        }

        /// Pending admin must accept the role to finalize admin transfership
        ///
        /// # Security
        /// * Only-pending-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn accept_admin(ref self: ContractState) {
            /// Get pending admin
            let pending_admin = self.pending_admin.read();

            /// # Error
            /// * `PENDING_CANT_BE_ZERO` - Avoid if caller is not pending admin
            assert(pending_admin.is_non_zero(), errors::PENDING_ADMIN_CANT_BE_ZERO);

            // Get caller
            let new_admin = get_caller_address();

            /// # Error
            /// * `ONLY_PENDING_ADMIN` - Avoid if caller is not pending admin
            assert(new_admin == pending_admin, errors::ONLY_PENDING_ADMIN);

            // Admin up until now
            let old_admin = self.admin.read();

            /// Store new admin
            self.admin.write(new_admin);

            /// # Event
            /// * `NewAdmin`
            self.emit(events::NewAdmin { old_admin, new_admin });
        }

        /// Set the periphery contract that is currently used by Cygnus frontend
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn set_cygnus_altair(ref self: ContractState, new_cygnus_altair: ContractAddress) {
            // Check sender is admin
            self._check_admin();

            /// Periphery until now
            let old_cygnus_altair = self.cygnus_altair.read();

            /// Write new periphery to storage
            self.cygnus_altair.write(new_cygnus_altair);

            /// # Event
            /// * `NewCygnusAltair`
            self.emit(events::NewCygnusAltair { old_cygnus_altair, new_cygnus_altair });
        }

        /// Sets the x1 vault on Starknet
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn set_cygnus_x1_vault(ref self: ContractState, new_cygnus_x1_vault: ContractAddress) {
            // Check sender is admin
            self._check_admin();

            /// X1 Vault until now
            let old_cygnus_x1_vault = self.cygnus_x1_vault.read();

            /// Write new vault to storage
            self.cygnus_x1_vault.write(new_cygnus_x1_vault);

            /// # Event
            /// * `NewCygnusX1Vault`
            self.emit(events::NewCygnusX1Vault { old_cygnus_x1_vault, new_cygnus_x1_vault });
        }

        /// Sets the CYG rewarder contract on Starknet (this should really only be set once...)
        ///
        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * IHangar18
        fn set_cygnus_pillars(ref self: ContractState, new_cygnus_pillars: ContractAddress) {
            /// Check sender is admin
            self._check_admin();

            /// Pillars until now
            let old_cygnus_pillars = self.cygnus_pillars.read();

            /// Write new pillars to storage
            self.cygnus_pillars.write(new_cygnus_pillars);

            /// # Event
            /// * `NewCygnusPillars`
            self.emit(events::NewCygnusPillars { old_cygnus_pillars, new_cygnus_pillars });
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Hangar18 - Internal
    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        /// Checks msg.sender is admin
        ///
        /// # Security
        /// * Checks that caller is admin
        #[inline(always)]
        fn _check_admin(self: @ContractState) {
            /// Get admin address from the hangar18
            let admin = self.admin.read();

            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == admin, errors::ONLY_ADMIN)
        }
    }
}
