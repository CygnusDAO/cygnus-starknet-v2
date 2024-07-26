use cygnus::core::borrowable::{IBorrowableDispatcher, IBorrowableDispatcherTrait};
use cygnus::periphery::altair_x::{IAltairXDispatcher, IAltairXDispatcherTrait};
use cygnus::types::periphery::{Aggregator};

// Libraries
use starknet::ContractAddress;

/// # Interface - Altair
#[starknet::interface]
pub trait IAltair<T> {
    /// -------------------------------------------------------------------------------------------------------
    ///                                         CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// # Returns
    /// * Name of the router (`Altair`)
    fn name(self: @T) -> felt252;

    /// # Returns
    /// * The version of this router
    fn version(self: @T) -> felt252;

    /// # Returns
    /// * The address of hangar18 on Starknet
    fn hangar18(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the current admin, the pool/orbiter deployer
    fn admin(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of USD
    fn usd(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of native token (ie WETH)
    fn native_token(self: @T) -> ContractAddress;

    /// # Returns
    /// * The addres of the Avnu Exchange router
    fn avnu_exchange(self: @T) -> ContractAddress;

    /// # Returns
    /// * The addres of the Fibrous Router V2
    fn fibrous_router(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of the Jediswap Router
    fn jediswap_router(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of Ekubo's Router v2.0.1
    fn ekubo_router(self: @T) -> ContractAddress;

    /// # Returns
    /// * The address of Ekubo Core
    fn ekubo_core(self: @T) -> ContractAddress;

    /// # Arguments
    /// * `extension_id` - The ID of an extension
    ///
    /// # Returns
    /// * The extension address
    fn all_extensions(self: @T, extension_id: u32) -> ContractAddress;

    /// # Arguments
    /// * `extension` - The address of the periphery extension
    ///
    /// # Returns
    /// * Whether the `extension` has been added to this contract or not
    fn is_extension(self: @T, extension: ContractAddress) -> bool;

    /// # Arguments
    /// * `cygnus_vault` - The address of a borrowable, collateral or lp token address
    ///
    /// # Returns
    /// * The extension address
    fn get_extension(self: @T, cygnus_vault: ContractAddress) -> ContractAddress;

    /// # Returns
    /// * The total amount of extensions we have initialized
    fn all_extensions_length(self: @T) -> u32;

    /// # Arguments
    /// * `shuttle_id` - Unique lending pool ID
    ///
    /// # Returns
    /// * The extension that is currently being used for a lending pool id
    fn get_shuttle_extension(self: @T, shuttle_id: u32) -> ContractAddress;

    /// Get assets out of token0 and token1 by burning `shares` of `lp_token`
    ///
    /// # Arguments
    /// * `lp_token` - The address of the LP Token
    /// * `shares` - The shares being burnt
    ///
    /// # Returns
    /// * The amount of token0 and token1 received
    fn get_assets_for_shares(self: @T, lp_token: ContractAddress, shares: u128) -> (u128, u128);

    /// -------------------------------------------------------------------------------------------------------
    ///                                      NON-CONSTANT FUNCTIONS
    /// -------------------------------------------------------------------------------------------------------

    /// Main function used to borrow stablecoins
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `amount` - The amount of USD to borrow
    /// * `recipient` - The address of the recipient of the loan
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    fn borrow(
        ref self: T, borrowable: IBorrowableDispatcher, borrow_amount: u128, recipient: ContractAddress, deadline: u64
    );

    /// Borrows USDC and buys more LP, depositing back in Cygnus and minting CygLP to the caller
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP Token
    /// * `collateral` - The address of the Cygnus collateral
    /// * `borrowable` - The address of the Cygnus borrowable
    /// * `borrow_amount` - The amount of USDC to convert into LP
    /// * `lp_amount_min` - The minimum allowed of LP to be minted, else reverts
    /// * `deadline` - TX expires after this timestamp
    /// * `swapdata` - The swapdata for the aggregators (empty if performed on-chain via sithswap, jediswap, etc.)
    ///
    /// # Returns
    /// * The amount of LP minted
    fn leverage(
        ref self: T,
        lp_token_pair: ContractAddress,
        collateral: ContractAddress,
        borrowable: ContractAddress,
        borrow_amount: u128,
        lp_amount_min: u128,
        deadline: u64,
        aggregator: Aggregator,
        swapdata: Array<Span<felt252>>
    ) -> u128;

    /// Burns the LP and buys USDC, repaying any debt the user may have (if any) and burning the user's CygLP
    ///
    /// # Arguments
    /// * `lp_token_pair` - The address of the LP Token
    /// * `collateral` - The address of the Cygnus collateral
    /// * `borrowable` - The address of the Cygnus borrowable
    /// * `cyg_lp_amount` - The amount of CygLP to deleverage
    /// * `usd_amount_min` - The minimum allowed of usdc to be received by redeeming `cyg_lp_amount` and selling assets
    /// * `deadline` - TX expires after this timestamp
    /// * `swapdata` - The swapdata for the aggregators (empty if performed on-chain via sithswap, jediswap, etc.)
    ///
    /// # Returns
    /// * The amount of LP minted
    fn deleverage(
        ref self: T,
        lp_token_pair: ContractAddress,
        collateral: ContractAddress,
        borrowable: ContractAddress,
        cyg_lp_amount: u128,
        usd_amount_min: u128,
        deadline: u64,
        aggregator: Aggregator,
        swapdata: Array<Span<felt252>>
    ) -> u128;

    /// Main function used to repay a loan
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `repay_amount` - The amount of USD to repay
    /// * `borrower` - The address of the borrower whose loan we are repaying
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    fn repay(ref self: T, borrowable: ContractAddress, repay_amount: u128, borrower: ContractAddress, deadline: u64);

    /// Main liquidate function to repay a loan and seize CygLP
    ///
    /// # Arguments
    /// * `borrowable` - The address of a Cygnus borrowable
    /// * `repay_amount` - The amount of USD to repay
    /// * `borrower` - The address of the borrower whose loan we are repaying
    /// * `recipient` - The address of the recipient of the CygLP
    /// * `deadline` - The maximum timestamp allowed for tx to succeed
    ///
    /// # Returns
    /// * The total amount of USD repaid
    /// * The total amount of CygLP seized from the borrower and received
    fn liquidate(
        ref self: T,
        borrowable: ContractAddress,
        repay_amount: u128,
        borrower: ContractAddress,
        recipient: ContractAddress,
        deadline: u64
    ) -> (u128, u128);

    /// Main function to flash liquidate borrows. Ie, liquidating a user without needing to have USD
    ///
    /// # Arguments
    /// `borrowable` - The address of the CygnusBorrow contract
    /// `amountMax` - The maximum amount to liquidate
    /// `borrower` - The address of the borrower
    /// `deadline` - The time by which the transaction must be included to effect the change
    /// `dexAggregator` - The dex used to sell the collateral (0 for Paraswap, 1 for 1inch)
    /// `swapdata` - Calldata to swap
    ///
    /// # Returns
    /// * The USDC amount received
    fn flash_liquidate(
        ref self: T,
        borrowable: ContractAddress,
        collateral: ContractAddress,
        repay_amount: u128,
        borrower: ContractAddress,
        deadline: u64,
        aggregator: Aggregator,
        swapdata: Array<Span<felt252>>
    ) -> u128;

    /// -------------------------------------------------------------------------------------------------------
    ///                                              CALLBACKS
    /// -------------------------------------------------------------------------------------------------------

    /// Function that is called by the CygnusBorrow contract and decodes data to carry out the leverage
    /// Will only succeed if: Caller is borrow contract & Borrow contract was called by router
    /// 
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the borrow transaction (address of the router)
    /// * `borrow_amount` - The amount of USDC to leverage
    /// * `calldata` - The encoded byte data passed from the CygnusBorrow contract to the router
    ///
    /// # Returns
    /// * The amount of LP minted
    fn altair_borrow_09E(ref self: T, sender: ContractAddress, borrow_amount: u128, calldata: Array<felt252>) -> u128;

    /// Function that is called by the CygnusCollateral contract and decodes data to carry out the deleverage.
    /// Will only succeed if: Caller is collateral contract & collateral contract was called by router
    ///
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the redeem transaction (address of the router)
    /// * `redeem_amount` - The amount of LP to deleverage
    /// * `calldata` - The encoded byte data passed from the CygnusCollateral contract to the router
    ///
    /// # Returns
    /// * The amount of USDC received from deleveraging LP
    fn altair_redeem_u91A(ref self: T, sender: ContractAddress, redeem_amount: u128, calldata: Array<felt252>) -> u128;

    /// Function that is called by the CygnusBorrow contract to carry out the flash liqudiation.
    /// Will only succeed if: Caller is borrow contract & Borrow contract was called by router
    ///
    /// # Arguments
    /// * `sender` - Address of the contract that initialized the borrow transaction (address of the router)
    /// * `cyg_lp_amount` - The amount of CygLP seized
    /// * `repay_amount` - The amount of USDC that the borrowable contract expects back
    /// * `calldata` - The encoded byte data passed from the CygnusBorrow contract to the router
    ///
    /// # Returns
    /// * The amount of LP minted
    fn altair_liquidate_f2x(
        ref self: T, sender: ContractAddress, cyg_lp_amount: u128, repay_amount: u128, calldata: Array<felt252>
    );

    /// -------------------------------------------------------------------------------------------------------
    ///                                            ADMIN
    /// -------------------------------------------------------------------------------------------------------

    /// Admin sets a new extension
    ///
    /// # Arguments
    /// * `shuttle_id` - The ID of the shuttle we are setting the extension for
    ///
    /// # Security
    /// * Only-admin
    fn set_altair_extension(ref self: T, shuttle_ids: Array<u32>, extension: IAltairXDispatcher);
}
