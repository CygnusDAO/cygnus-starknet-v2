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
//      EKUBO Oracle                                                           
//  ═══════════════════════════════════════════════════════════════════════════════════════════════════════════  

#[starknet::contract]
pub mod CygnusNebula {
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     1. IMPORTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    use core::num::traits::Zero;
    use cygnus::nebula::{errors, events};
    use cygnus::types::ekubo::{PoolKeyCYG, PositionKeyCYG};
    use cygnus::types::nebula::{NebulaOracle};
    use cygnus::types::pragma::{DataType};
    use cygnus::types::pragma::{IOracleABIDispatcher, IOracleABIDispatcherTrait};
    use cygnus::utils::addresses::{USDC, PRAGMA, EKUBO_CORE};
    use cygnus::utils::math::MathLib::MathLibTrait;
    use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     2. EVENTS
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewLPOracle: events::NewLPOracle
    }

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     3. STORAGE
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[storage]
    struct Storage {
        admin: ContractAddress,
        denomination_token: ERC20ABIDispatcher,
        denomination_token_feed: felt252,
        ekubo_core: ICoreDispatcher,
        pragma_oracle: IOracleABIDispatcher,
        nebula_oracles: LegacyMap<PoolKeyCYG, NebulaOracle>,
        all_oracles: LegacyMap<u8, NebulaOracle>,
        token_to_feed: LegacyMap<ContractAddress, felt252>,
        total_oracles: u8
    }

    /// The denomination price feed. To replace just replace `USDC` with other supported asset by Pragma
    /// and replace `DENOMINATION_SCALAR` with the correct asset scalar (ie. The price feed returns the price
    /// of the asset in 6 decimals, so denom scalar is 10 ** (18 -6))
    const DENOMINATION_PRICE_FEED: felt252 = 'USDC/USD';

    /// 8 is the decimals used by Pragma oracles for most SPOT price feeds
    const AGGREGATOR_SCALAR: u128 = 10000000000; // 10 ** (18 - 8)

    /// The scalar of the decimals used by Pragma for the DENOMINATION_PRICE_FEED
    const DENOMINATION_PRICE_SCALAR: u128 = 1000000000000; // 10 ** (18 - 6)

    // AS OF jul 26 these are the Pragma feeds:
    //
    // BTC/USD	  18669995996566340
    // ETH/USD	  19514442401534788
    // WBTC/USD	  6287680677296296772
    // WBTC/BTC	  6287680677295051843
    // BTC/EUR	  18669995995518290
    // WSTETH/USD	412383036120118613857092
    // LORDS/USD	1407668255603079598916
    // UNI/USD	  24011449254105924
    // STRK/USD	  6004514686061859652
    // ZEND/USD	  6504691291565413188
    //
    // We will keep adding them as they add more

    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     4. CONSTRUCTOR
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress,) {
        /// The ERC20 token that prices are denominated in
        self.admin.write(admin);
        self.denomination_token_feed.write(DENOMINATION_PRICE_FEED);

        // USDC
        self.denomination_token.write(ERC20ABIDispatcher { contract_address: USDC.try_into().unwrap() });

        /// Pragma oracle on mainnet
        self.pragma_oracle.write(IOracleABIDispatcher { contract_address: PRAGMA.try_into().unwrap() });

        /// Ekubo core
        self.ekubo_core.write(ICoreDispatcher { contract_address: EKUBO_CORE.try_into().unwrap() })
    }


    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════
    ///     5. IMPLEMENTATION
    /// ═══════════════════════════════════════════════════════════════════════════════════════════════════════

    #[abi(embed_v0)]
    impl CygnusNebula of cygnus::nebula::ICygnusNebula<ContractState> {
        ///----------------------------------------------------------------------------------------------------
        ///                                        CONSTANT FUNCTIONS
        ///----------------------------------------------------------------------------------------------------

        /// # Implementation
        /// * ICygnusNebula
        fn name(self: @ContractState) -> ByteArray {
            "Cygnus: Ekubo Positions Oracle"
        }

        /// # Implementation
        /// * ICygnusNebula
        fn decimals(self: @ContractState) -> u8 {
            self.denomination_token.read().decimals()
        }

        /// # Implementation
        /// * ICygnusNebula
        fn all_oracles(self: @ContractState, oracle_id: u8) -> NebulaOracle {
            self.all_oracles.read(oracle_id)
        }

        /// # Implementation
        /// * ICygnusNebula
        fn nebula_oracle(self: @ContractState, pool_key: PoolKeyCYG) -> NebulaOracle {
            self.nebula_oracles.read(pool_key)
        }

        /// # Implementation
        /// * ICygnusNebula
        fn position_price_usd(self: @ContractState, pool_key: PoolKeyCYG, position_key: PositionKeyCYG) -> u128 {
            10 // TODO
        }

        /// # Implementation
        /// * ICygnusNebula
        fn nft_price_usd(self: @ContractState, nft_id: u64) -> u128 {
            10 // TODO
        }

        /// # Implementation
        /// * ICygnusNebula
        fn get_asset_price(self: @ContractState, asset: DataType) -> u128 {
            self.pragma_oracle.read().get_data_median(asset).price
        }

        /// # Implementation
        /// * ICygnusNebula
        fn get_asset_decimals(self: @ContractState, asset: DataType) -> u32 {
            self.pragma_oracle.read().get_decimals(asset)
        }

        /// # Implementation
        /// * ICygnusNebula
        fn denomination_token_price(self: @ContractState) -> u128 {
            /// DataType of asset for Pragma
            let asset = DataType::SpotEntry(self.denomination_token_feed.read());

            /// Price of denom in 18 decimals
            self.pragma_oracle.read().get_data_median(asset).price * DENOMINATION_PRICE_SCALAR
        }


        /// # Security
        /// * Only-admin
        ///
        /// # Implementation
        /// * ICygnusNebula
        fn initialize_pool_oracle(ref self: ContractState, pool_key: PoolKeyCYG) {
            self._check_admin();

            /// Get oracle for `lp_token_pair`
            let mut lp_oracle: NebulaOracle = self.nebula_oracles.read(pool_key);

            /// # Error
            /// * ALREADY_INIT - Revert if already initialized
            assert(!lp_oracle.initialized, errors::ORACLE_ALREADY_INITIALIZED);

            // Create dispatcher and unique oracle id
            let oracle_id = self.total_oracles.read();

            /// Mark as true, cannot be set again
            lp_oracle.initialized = true;

            /// Assign unique oracle id
            lp_oracle.oracle_id = oracle_id;

            lp_oracle.pool_key = pool_key;

            // This will throw if token is not supported by Pragma
            lp_oracle.price_feed0 = self._check_price_feed(pool_key.token0);
            lp_oracle.price_feed1 = self._check_price_feed(pool_key.token1);

            /// Write oracle to storage mapping and array
            self.nebula_oracles.write(pool_key, lp_oracle);
            self.all_oracles.write(oracle_id, lp_oracle);

            /// Increase oracle count
            self.total_oracles.write(oracle_id + 1);

            /// # Event
            /// * `NewLPOracle`
            self.emit(events::NewLPOracle { pool_key });
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
            assert(get_caller_address() == admin, errors::ONLY_ADMIN);
        }

        /// Checks we are tracking the pragma tokens
        #[inline(always)]
        fn _check_price_feed(self: @ContractState, token: ContractAddress) -> felt252 {
            let price_feed = self.token_to_feed.read(token);
            assert(price_feed.is_non_zero(), 'NO');
            price_feed
        }
    }
}
