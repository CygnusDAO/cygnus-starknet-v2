//  SPDX-License-Identifier: AGPL-3.0-or-later
//
//  dao_reserves.cairo
//
//  Copyright (C) 2023 CygnusDAO
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

//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════  
//   .              .            .               .      🛰️     .           .                .           .
//          █████████     🛰️      ---======*.                                                 .           ⠀
//         ███░░░░░███                                               📡                🌔                      . 
//        ███     ░░░  █████ ████  ███████ ████████   █████ ████  █████        ⠀
//       ░███         ░░███ ░███  ███░░███░░███░░███ ░░███ ░███  ███░░      .     .⠀           .           .
//       ░███          ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███ ░░█████       ⠀
//       ░░███     ███ ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███  ░░░░███              .             .⠀
//        ░░█████████  ░░███████ ░░███████ ████ █████ ░░████████ ██████     .----===*  ⠀
//         ░░░░░░░░░    ░░░░░███  ░░░░░███░░░░ ░░░░░   ░░░░░░░░ ░░░░░░            .                           .⠀
//                      ███ ░███  ███ ░███                .                 .                 .⠀
//       .             ░░██████  ░░██████        🛰️                        🛰️             .                 .     
//                      ░░░░░░    ░░░░░░      -------=========*                      .                     ⠀
//          .                            .       .          .            .                        .             .⠀
//       
//       DAO RESERVES - https://cygnusdao.finance                                                          .                     .
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice This contract receives all reserves and fees (if applicable) from Core contracts.
//
//         From the borrowable, this contract receives the reserve rate from borrows in the form of CygUSD. Note
//         that the reserves are actually kept in CygUSD. The reserve rate is manually updatable at core contracts
//         by admin, it is by default set to 10% with the option to set between 0% to 20%.
//
//         From the collateral, this contract receives liquidation fees in the form of CygLP. The liquidation fee
//         is also an updatable parameter by admins, and can be set anywhere between 0% and 10%. It is by default
//         set to 1%. This means that when CygLP is seized from the borrower, an extra 1% of CygLP is taken also.
//
// @title  CygnusDAOReserves
// @author CygnusDAO
//
//                                             3.A. Harvest LP rewards
//                  +------------------------------------------------------------------------------+
//                  |                                                                              |
//                  |                                                                              ▼
//           +------------+                         +----------------------+            +--------------------+
//           |            |  3.B. Mint USD reserves |                      |            |                    |
//           |    CORE    |>----------------------► |     DAO RESERVES     |>---------► |      X1 VAULT      |
//           |            |                         |   (this contract)    |            |                    |
//           +------------+                         +----------------------+            +--------------------+
//              ▲      |                                                                      ▲         |
//              |      |    2. Track borrow/lend    +----------------------+                  |         |
//              |      +--------------------------► |     CYG REWARDER     |                  |         |  6. Claim LP rewards + USDC
//              |                                   +----------------------+                  |         |
//              |                                            ▲    |                           |         |
//              |                                            |    | 4. Claim CYG              |         |
//              |                                            |    |                           |         |
//              |                                            |    ▼                           |         |
//              |                                   +------------------------+                |         |
//              |    1. Deposit USDC / Liquidity    |                        |  5. Stake CYG  |         |
//              +-----------------------------------|    LENDERS/BORROWERS   |>---------------+         |
//                                                  |         ʕ•ᴥ•ʔ          |                          |
//                                                  +------------------------+                          |
//                                                             ▲                                        |
//                                                             |                                        |
//                                                             +----------------------------------------+
//                                                                       LP Rewards + USDC
//
//      Important: Main functionality of this contract is to split the reserves received to two main addresses:
//                 `daoReserves` and `cygnusX1Vault`
//
//                 This contract receives only CygUSD and CygLP (vault tokens of the Core contracts). The amount of
//                 assets received by the X1 Vault depends on the `x1VaultWeight` variable. Basically this contract
//                 redeems an amount of CygUSD shares for USDC and sends it to the vault so users can claim USD from
//                 reserves. The DAO receives the leftover shares which are NOT to be redeemed. These shares sit in
//                 the DAO reserves accruing interest (in the case of CygUSD) or earning from trading fees (in the
//                 case of CygLP).
//

/// # Title
/// * `CygnusDAOReserves`
///
/// # Description
/// * Where all DAO reserves go from the borrowable and collateral contracts
///
/// # Author
/// * CygnusDAO
#[starknet::contract]
mod CygnusDAOReserves {
    use core::num::traits::Zero;
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    use cygnus::core::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
    use cygnus::core::collateral::{ICollateralDispatcher, ICollateralDispatcherTrait};
    use cygnus::core::hangar18::{IHangar18Dispatcher, IHangar18DispatcherTrait};
    use cygnus::dao::reserves::{events, errors};
    use cygnus::types::shuttle::{ShuttleDAOReserves};
    use cygnus::utils::math::MathLib::MathLibTrait;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        guard: bool,
        dao_lock: u64,
        all_shuttles_length: u32,
        all_shuttles: LegacyMap::<u32, ShuttleDAOReserves>,
        usd: ERC20ABIDispatcher,
        hangar18: IHangar18Dispatcher,
        cygnus_dao_safe: ContractAddress,
        cygnus_x1_vault: ContractAddress,
        dao_weight: u128,
        x1_vault_weight: u128,
        private_banker: bool,
        cyg_token: ERC20ABIDispatcher
    }

    /// For the DAO lock
    const NINETY_DAYS: u64 = 7776000;

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FundX1VaultUSD: events::FundX1VaultUSD,
        FundX1VaultUSDAll: events::FundX1VaultUSDAll,
        FundDAOSafeCygLP: events::FundDAOSafeCygLP,
        FundDAOSafeCygLPAll: events::FundDAOSafeCygLPAll,
        NewX1VaultWeight: events::NewX1VaultWeight,
        CygTokenSet: events::CygTokenSet,
        PrivateBankerSwitch: events::PrivateBankerSwitch,
        CygTokenClaim: events::CygTokenClaim,
        NewDAOSafe: events::NewDAOSafe,
        NewX1Vault: events::NewX1Vault
    }


    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, hangar18: IHangar18Dispatcher) {
        /// USDC on Starknet
        self.usd.write(ERC20ABIDispatcher { contract_address: hangar18.usd() });

        /// Factory
        self.hangar18.write(hangar18);

        /// CYG tokens sent here are locked for 90 days post deployment
        self.dao_lock.write(get_block_timestamp() + 7776000);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusDAOReservesImpl of cygnus::dao::reserves::ICygnusDAOReserves<ContractState> {
        /// ---------------------------------------------------------------------------------------------------
        ///                                        CONSTANT FUNCTIONS
        /// ---------------------------------------------------------------------------------------------------

        /// @inheritdoc ICygnusDAOReserves
        fn name(self: @ContractState) -> ByteArray {
            "Cygnus: DAO Reserves"
        }

        /// @inheritdoc ICygnusDAOReserves
        fn version(self: @ContractState) -> ByteArray {
            "0.1.0"
        }

        /// @inheritdoc ICygnusDAOReserves
        fn cygnus_dao_safe(self: @ContractState) -> ContractAddress {
            self.cygnus_dao_safe.read()
        }

        /// @inheritdoc ICygnusDAOReserves
        fn cygnus_x1_vault(self: @ContractState) -> ContractAddress {
            self.cygnus_x1_vault.read()
        }

        /// @inheritdoc ICygnusDAOReserves
        fn hangar18(self: @ContractState) -> ContractAddress {
            self.hangar18.read().contract_address
        }

        /// @inheritdoc ICygnusDAOReserves
        fn usd(self: @ContractState) -> ContractAddress {
            self.usd.read().contract_address
        }

        /// @inheritdoc ICygnusDAOReserves
        fn x1_vault_weight(self: @ContractState) -> u128 {
            self.x1_vault_weight.read()
        }

        /// @inheritdoc ICygnusDAOReserves
        fn dao_weight(self: @ContractState) -> u128 {
            self.dao_weight.read()
        }

        /// @inheritdoc ICygnusDAOReserves
        fn cyg_token(self: @ContractState) -> ContractAddress {
            self.cyg_token.read().contract_address
        }

        /// @inheritdoc ICygnusDAOReserves
        fn dao_lock(self: @ContractState) -> u64 {
            self.dao_lock.read()
        }

        /// @inheritdoc ICygnusDAOReserves
        fn private_banker(self: @ContractState) -> bool {
            self.private_banker.read()
        }

        /// @inheritdoc ICygnusDAOReserves
        fn all_shuttles_length(self: @ContractState) -> u32 {
            self.all_shuttles_length.read()
        }

        /// @inheritdoc ICygnusDAOReserves
        fn all_shuttles(self: @ContractState, shuttle_id: u32) -> ShuttleDAOReserves {
            self.all_shuttles.read(shuttle_id)
        }

        /// @inheritdoc ICygnusDAOReserves
        fn cyg_token_balance(self: @ContractState) -> u256 {
            self.cyg_token.read().balance_of(get_contract_address())
        }

        /// @inheritdoc ICygnusDAOReserves
        fn pending_x1_vault_usd(self: @ContractState) -> u128 {
            /// Get total lending pools added to the reserves contract
            let total_shuttles = self.all_shuttles_length.read();

            let mut length = 0;
            let mut usd = 0;

            /// The weight for the x1 vault
            let x1_vault_weight = self.x1_vault_weight.read();

            loop {
                /// Break clause
                if length == total_shuttles {
                    break;
                }

                /// Get shuttle at index `length`
                let shuttle = self.all_shuttles.read(length);

                /// Get our balance of CygUSD
                let cyg_usd_balance = 0; // TODO shuttle.borrowable.balance_of(get_contract_address());

                /// The current exchange rate of CygUSD - USDC
                let exchange_rate = shuttle.borrowable.exchange_rate();

                /// Increase USD
                usd += cyg_usd_balance.mul_wad(exchange_rate).mul_wad(x1_vault_weight);

                length += 1;
            };

            usd
        }

        /// --------------------------------------------------------------------------------------------------------
        ///                                      NON-CONSTANT FUNCTIONS
        /// --------------------------------------------------------------------------------------------------------

        /// @inheritdoc ICygnusDAOReserves
        fn fund_x1_vault_usd(ref self: ContractState, shuttle_id: u32) -> (u128, u128) {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get borrowable for this shuttle id
            let borrowable = self.all_shuttles.read(shuttle_id).borrowable;

            /// Split between DAO and X1 Vault
            let (dao_shares, assets) = self
                ._redeem_and_fund_usd(
                    borrowable, self.x1_vault_weight.read(), self.cygnus_x1_vault.read(), self.cygnus_dao_safe.read()
                );

            /// # Event
            /// * `FundX1VaultUSD` - Log the transfer of USDC to the vault and CygUSD to the safe
            self.emit(events::FundX1VaultUSD { borrowable, dao_shares, assets });

            (dao_shares, assets)
        }

        /// @inheritdoc ICygnusDAOReserves
        fn fund_x1_vault_usd_all(ref self: ContractState) -> (u128, u128) {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get length of shuttles
            let total_shuttles = self.all_shuttles_length.read();

            /// Return variables of CygUSD shares and USDC assets
            let mut dao_shares = 0;
            let mut assets = 0;

            let mut index = 0;

            /// Savings
            let x1_vault_weight = self.x1_vault_weight.read();
            let cygnus_x1_vault = self.cygnus_x1_vault.read();
            let cygnus_dao_safe = self.cygnus_dao_safe.read();

            loop {
                /// Index
                if index == total_shuttles {
                    break;
                }

                /// Get borrowable  from stored shuttles
                let borrowable = self.all_shuttles.read(index).borrowable;

                /// Split between DAO and X1 Vault
                let (_dao_shares, _assets) = self
                    ._redeem_and_fund_usd(borrowable, x1_vault_weight, cygnus_x1_vault, cygnus_dao_safe);

                /// Accumulate shares and assets
                dao_shares += _dao_shares;
                assets += _assets;

                /// Increase index
                index += 1;
            };

            /// # Event
            /// * `FundX1VaultUSDAll` - Logs when we redeem all CygUSD and transfer to vault or dao
            self.emit(events::FundX1VaultUSDAll { total_shuttles, dao_shares, assets });

            (dao_shares, assets)
        }

        /// @inheritdoc ICygnusDAOReserves
        fn fund_safe_cyg_lp(ref self: ContractState, shuttle_id: u32) -> u128 {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get collateral for this shuttle id
            let collateral = self.all_shuttles.read(shuttle_id).collateral;

            /// Split between DAO and X1 Vault
            let dao_shares = self._fund_cyg_lp(collateral);

            /// # Event
            /// * `FundX1VaultUSD` - Log the transfer of USDC to the vault and CygUSD to the safe
            self.emit(events::FundDAOSafeCygLP { dao_shares });

            dao_shares
        }

        /// @inheritdoc ICygnusDAOReserves
        fn fund_safe_cyg_lp_all(ref self: ContractState) -> u128 {
            /// If private banker is enabled, then caller must be hangar18 admin
            if (self.private_banker.read()) {
                self._check_admin();
            }

            /// Get length of shuttles
            let total_shuttles = self.all_shuttles_length.read();

            /// Return variable of CygLP shares
            let mut dao_shares = 0;

            let mut index = 0;

            loop {
                /// Index
                if index == total_shuttles {
                    break;
                }

                /// Get collateral from stored shuttles
                let collateral = self.all_shuttles.read(index).collateral;

                /// Fund CygLP to dao safe
                let _dao_shares = self._fund_cyg_lp(collateral);

                /// Accumulate CygLP shares
                dao_shares += _dao_shares;

                /// Increase index
                index += 1;
            };

            /// # Event
            /// * `FundDAOSafeCygLPAll` - Logs when we transfer all CygLP to the safe
            self.emit(events::FundDAOSafeCygLPAll { total_shuttles, dao_shares });

            dao_shares
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Hangar18
        fn add_shuttle(
            ref self: ContractState,
            shuttle_id: u32,
            borrowable: IBorrowableDispatcher,
            collateral: ICollateralDispatcher
        ) {
            /// # Error
            /// * Can only be called by hangar18 directly
            assert(get_caller_address() == self.hangar18.read().contract_address, errors::CALLER_NOT_HANGAR18);

            /// Create quick view to store here
            let shuttle: ShuttleDAOReserves = ShuttleDAOReserves { shuttle_id, borrowable, collateral };

            /// Get length
            let total_shuttles = self.all_shuttles_length.read();

            /// Write to storage
            self.all_shuttles.write(total_shuttles, shuttle);

            /// Increase length
            self.all_shuttles_length.write(total_shuttles + 1);
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Admin
        fn set_x1_vault_weight(ref self: ContractState, new_weight: u128) {
            /// Check admin
            self._check_admin();

            let old_weight = self.x1_vault_weight.read();

            self.x1_vault_weight.write(new_weight);
            self.dao_weight.write(1_000_000_000_000_000_000 - new_weight);

            /// # Event
            /// * NewX1VaultWeight
            self.emit(events::NewX1VaultWeight { old_weight, new_weight });
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Admin
        fn set_cyg_token(ref self: ContractState, cyg_token: ERC20ABIDispatcher) {
            /// Check admin
            self._check_admin();

            /// # Error
            /// * Can only be set once
            assert(self.cyg_token.read().contract_address.is_zero(), errors::CYG_TOKEN_ALREADY_SET);

            /// Update
            self.cyg_token.write(cyg_token);

            /// # Event
            /// * CygTokenSet
            self.emit(events::CygTokenSet { cyg_token });
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Admin
        fn sweep_token(ref self: ContractState, token: ContractAddress, amount: u256) {
            /// Check admin
            self._check_admin();

            /// # Error
            /// * Avoid sweeping CYG
            assert(token != self.cyg_token.read().contract_address, errors::CANT_SWEEP_CYG);

            /// Transfer to caller
            if amount.is_non_zero() {
                ERC20ABIDispatcher { contract_address: token }.transfer(get_caller_address(), amount);
            }
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Admin
        fn claim_cyg_token_dao(ref self: ContractState, amount: u256, to: ContractAddress) {
            /// Check admin
            self._check_admin();

            /// # Error
            /// * Make sure we are past the dao lock timestamp of 90 days
            assert(get_block_timestamp() > self.dao_lock.read(), errors::NOT_UNLOCKED_YET);

            /// # Error
            /// * Make sure that we have enough CYG in contract
            assert(amount < self.cyg_token_balance(), errors::NOT_ENOUGH_CYG_IN_RESERVES);

            self.cyg_token.read().transfer(to, amount);

            /// # Event
            /// * `CygTokenClaim` - Log when cyg token is claimed by admin
            self.emit(events::CygTokenClaim { amount, to });
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Admin
        fn switch_private_banker(ref self: ContractState) {
            /// Check admin
            self._check_admin();

            /// Get private banker status and switch
            let private_banker = !self.private_banker.read();

            /// Update to storage
            self.private_banker.write(private_banker);

            /// # Event
            /// * `PrivateBankerSwitch` - Logs when the private banker is switch on/off
            self.emit(events::PrivateBankerSwitch { private_banker })
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Admin
        fn set_cygnus_dao_safe(ref self: ContractState, new_safe: ContractAddress) {
            /// Check admin
            self._check_admin();

            /// Current safe
            let old_safe = self.cygnus_dao_safe.read();

            /// Update safe to storage
            self.cygnus_dao_safe.write(new_safe);

            /// # Event
            /// * `NewDAOSafe` - Logs when new safe is set for CygLP  and CygUSD
            self.emit(events::NewDAOSafe { old_safe, new_safe });
        }

        /// @inheritdoc ICygnusDAOReserves
        /// @custom:security Only-Admin
        fn set_cygnus_x1_vault(ref self: ContractState, new_vault: ContractAddress) {
            /// Check admin
            self._check_admin();

            /// Current vault
            let old_vault = self.cygnus_x1_vault.read();

            /// Update safe to storage
            self.cygnus_x1_vault.write(new_vault);

            /// # Event
            /// * `NewX1Vault` - Logs when new vault is set
            self.emit(events::NewX1Vault { old_vault, new_vault });
        }
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     6. INTERNAL LOGIC
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    /// # Hangar18 - Internal
    #[generate_trait]
    impl InternalDAOImpl of InternalDAOImplTrait {
        /// Redeems CygUSD for USDC according to the x1 vault weight and sends it to the x1 vault. The remaining
        /// CygUSD (which was not redeemed) is sent to the DAO safe
        ///
        /// # Arguments
        /// * `borrowable` - The address of the CygUSD
        /// * `x1_vault_weight` - The weight of the x1 vault
        /// * `cygnus_x1_vault` - The address of the x1 vault on Starknet
        /// * `cygnus_dao_safe` - The address of the dao safe
        ///
        /// # Returns
        /// * The amount of USDC sent to the x1 vault
        /// * The amount of CygUSD sent to the safe
        fn _redeem_and_fund_usd(
            ref self: ContractState,
            borrowable: IBorrowableDispatcher,
            x1_vault_weight: u128,
            cygnus_x1_vault: ContractAddress,
            cygnus_dao_safe: ContractAddress
        ) -> (u128, u128) {
            /// Avoid if zero
            if borrowable.contract_address.is_zero() {
                return (0, 0);
            }

            /// Force sync
            borrowable.sync();

            /// Our balance of CygUSD for this borrowable
            let total_shares = 0; // TODO borrowable.balance_of(get_contract_address());

            /// Get shares for the X1 Vault
            let x1_vault_shares = total_shares.mul_wad(x1_vault_weight);

            /// Shares for the DAO
            let dao_shares = total_shares - x1_vault_shares;

            let mut assets = 0;

            /// Redeem shares to vault
            if (x1_vault_shares > 0) {
                assets = borrowable.redeem(x1_vault_shares, cygnus_x1_vault, get_contract_address());
            }
            /// Send leftover shares to DAO cold wallet
            if (dao_shares > 0) { // TODO; borrowable.transfer(cygnus_dao_safe, dao_shares);
            }

            (dao_shares, assets)
        }

        /// Funds CygLP received from liquidation fees to the dao safe
        ///
        /// # Arguments
        /// * `collateral` - The address of the CygLP contract
        ///
        /// # Returns
        /// * The amount of CygLP sent to the dao safe
        fn _fund_cyg_lp(ref self: ContractState, collateral: ICollateralDispatcher) -> u128 {
            /// Escape if zero
            if collateral.contract_address.is_zero() {
                return (0);
            }

            /// Our balance of CygLP for this collateral
            let dao_shares: u128 = 0; // TODO collateral.balance_of(get_contract_address());

            /// Send all LP shares to DAO cold wallet
            if (dao_shares > 0) { // TODO; collateral.transfer(self.cygnus_dao_safe.read(), dao_shares);
            }

            dao_shares
        }
    }

    /// # Hangar18 - Internal
    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        /// Checks msg.sender is admin
        ///
        /// # Security
        /// * Checks that caller is admin
        #[inline(always)]
        fn _check_admin(self: @ContractState) {
            /// # Error
            /// * `ONLY_ADMIN` - Reverts if sender is not hangar18 admin 
            assert(get_caller_address() == self.hangar18.read().admin(), errors::ONLY_ADMIN)
        }
    }
}

