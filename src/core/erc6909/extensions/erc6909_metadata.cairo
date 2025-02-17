// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (token/erc6909/extensions/erc6909_votes.cairo)

use starknet::ContractAddress;

/// # ERC6909Metadata Component
///
/// The ERC6909Metadata component allows to set metadata to the individual token IDs.
/// The internal function `_update_token_metadata` should be used inside the ERC6909 Hooks.
#[starknet::component]
pub mod ERC6909MetadataComponent {
    use core::num::traits::Zero;
    use cygnus::core::erc6909::ERC6909Component;
    use cygnus::core::erc6909::interface;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        ERC6909Metadata_name: LegacyMap<u128, ByteArray>,
        ERC6909Metadata_symbol: LegacyMap<u128, ByteArray>,
        ERC6909Metadata_decimals: LegacyMap<u128, u8>,
    }

    #[embeddable_as(ERC6909MetadataImpl)]
    impl ERC6909Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of interface::IERC6909Metadata<ComponentState<TContractState>> {
        /// @notice Name of a given token.
        /// @param id The id of the token.
        /// @return The name of the token.
        fn name(self: @ComponentState<TContractState>, id: u128) -> ByteArray {
            self.ERC6909Metadata_name.read(id)
        }

        /// @notice Symbol of a given token.
        /// @param id The id of the token.
        /// @return The symbol of the token.
        fn symbol(self: @ComponentState<TContractState>, id: u128) -> ByteArray {
            self.ERC6909Metadata_symbol.read(id)
        }

        /// @notice Decimals of a given token.
        /// @param id The id of the token.
        /// @return The decimals of the token.
        fn decimals(self: @ComponentState<TContractState>, id: u128) -> u8 {
            self.ERC6909Metadata_decimals.read(id)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC6909: ERC6909Component::HasComponent<TContractState>,
        +ERC6909Component::ERC6909HooksTrait<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// @notice Updates the metadata of a token ID.
        /// @notice Ideally this function should be called in a `before_update` or `after_update` hook during mints.
        /// @param sender The address of the sender.
        /// @param id The ID of the token.
        /// @param name The name of the token.
        /// @param symbol The symbol of the token.
        /// @param decimals The decimals of the token.
        fn _update_token_metadata(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            id: u128,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8
        ) {
            let zero_address = Zero::zero();

            // In case of new ID mints update the token metadata
            if (sender == zero_address) {
                let token_metadata_exists = self._token_metadata_exists(id);
                if (!token_metadata_exists) {
                    self._set_token_metadata(id, name, symbol, decimals)
                }
            }
        }

        /// @notice Checks if a token has metadata at the time of minting.
        /// @param id The ID of the token.
        /// @return Whether or not the token has metadata.
        fn _token_metadata_exists(self: @ComponentState<TContractState>, id: u128) -> bool {
            return self.ERC6909Metadata_name.read(id).len() > 0;
        }

        /// @notice Updates the token metadata for `id`.
        /// @param id The ID of the token.
        /// @param name The name of the token.
        /// @param decimals The decimals of the token.
        fn _set_token_metadata(
            ref self: ComponentState<TContractState>, id: u128, name: ByteArray, symbol: ByteArray, decimals: u8
        ) {
            self._set_token_name(id, name);
            self._set_token_symbol(id, symbol);
            self._set_token_decimals(id, decimals);
        }

        /// @notice Sets the token name.
        /// @param id The id of the token.
        /// @param name The name of the token.
        fn _set_token_name(ref self: ComponentState<TContractState>, id: u128, name: ByteArray) {
            self.ERC6909Metadata_name.write(id, name);
        }

        /// @notice Sets the token symbol.
        /// @param id The id of the token.
        /// @param symbol The symbol of the token.
        fn _set_token_symbol(ref self: ComponentState<TContractState>, id: u128, symbol: ByteArray) {
            self.ERC6909Metadata_symbol.write(id, symbol);
        }

        /// @notice Sets the token decimals.
        /// @param id The id of the token.
        /// @param decimals The decimals of the token.
        fn _set_token_decimals(ref self: ComponentState<TContractState>, id: u128, decimals: u8) {
            self.ERC6909Metadata_decimals.write(id, decimals);
        }
    }
}
