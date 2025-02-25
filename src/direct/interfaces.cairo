use starknet::{ContractAddress, ClassHash};
use market::token::{Token, ERC20Amount};

/// Interface for managing direct contracts.
#[starknet::interface]
trait IDirectManager<TContractState> {
    /// Creates a new single offer.
    fn new_single(
        ref self: TContractState,
        offer: Array<Token>,
        erc20_address: ContractAddress,
        price: u256,
        expiry: u64,
        tax_ppm: u32,
        guaranteed: bool,
    );

    /// Creates a new multiple offer.
    fn new_multiple(
        ref self: TContractState,
        offer: Array<Token>,
        ask: Array<ERC20Amount>,
        expiry: u64,
        tax_ppm: u32,
        guaranteed: bool,
    );

    /// Creates a new one-of offer.
    fn new_one_of(
        ref self: TContractState,
        offer: Array<Token>,
        prices: Array<(ContractAddress, u256)>,
        expiry: u64,
        tax_ppm: u32,
        guaranteed: bool,
    );

    /// Sets the class hash for a single offer.
    fn set_single_class_hash(ref self: TContractState, guaranteed: bool, class_hash: ClassHash);

    /// Sets the class hash for a multiple offer.
    fn set_multiple_class_hash(ref self: TContractState, guaranteed: bool, class_hash: ClassHash);

    /// Sets the class hash for a one-of offer.
    fn set_one_of_class_hash(ref self: TContractState, guaranteed: bool, class_hash: ClassHash);

    /// Gets the class hash for a single offer.
    fn get_single_class_hash(self: @TContractState, guaranteed: bool) -> ClassHash;

    /// Gets the class hash for a multiple offer.
    fn get_multiple_class_hash(self: @TContractState, guaranteed: bool) -> ClassHash;

    /// Gets the class hash for a one-of offer.
    fn get_one_of_class_hash(self: @TContractState, guaranteed: bool) -> ClassHash;

    /// Sets the buyer for an offer.
    fn set_bought(ref self: TContractState, buyer: ContractAddress);

    /// Pauses the contract.
    fn set_paused(ref self: TContractState);

    /// Resumes the contract.
    fn set_resumed(ref self: TContractState);

    /// Closes the contract.
    fn set_closed(ref self: TContractState);

    /// Sets a new expiry for the offer.
    fn set_new_expiry(ref self: TContractState, expiry: u64);

    /// Sets a new offer.
    fn set_new_offer(ref self: TContractState, offer: Span<Token>, offer_hash: felt252);

    /// Sets a new price for a single offer.
    fn set_single_new_price(ref self: TContractState, price: u256);

    /// Sets a new price for a one-of offer.
    fn set_one_of_new_price(ref self: TContractState, erc20_address: ContractAddress, price: u256);

    /// Removes a token from a one-of offer.
    fn set_one_of_remove_token(ref self: TContractState, erc20_address: ContractAddress);

    /// Sets a new ask for a multiple offer.
    fn set_multiple_new_ask(ref self: TContractState, ask: Span<ERC20Amount>, ask_hash: felt252);

    /// Grants ownership to a contract address.
    fn grant_owner(ref self: TContractState, contract_address: ContractAddress);

    /// Revokes ownership from a contract address.
    fn revoke_owner(ref self: TContractState, contract_address: ContractAddress);

    /// Checks if a contract address is an owner.
    fn is_owner(self: @TContractState, contract_address: ContractAddress) -> bool;

    /// Sets the beneficiary of the contract.
    fn set_beneficiary(ref self: TContractState, beneficiary: ContractAddress);

    /// Sets the tax in parts per million.
    fn set_tax(ref self: TContractState, ppm: u32);

    /// Gets the beneficiary of the contract.
    fn beneficiary(self: @TContractState) -> ContractAddress;

    /// Gets the tax in parts per million.
    fn tax_ppm(self: @TContractState) -> u32;
}

/// Interface for contracts owned by this contract.
#[starknet::interface]
trait IDirectThisOwned<TContractState> {}

/// Interface for single direct offers.
#[starknet::interface]
trait IDirectSingle<TContractState> {
    /// Purchases a single offer.
    fn purchase(ref self: TContractState, offer_hash: felt252, price: u256);

    /// Sets the price for a single offer.
    fn set_price(ref self: TContractState, price: u256);

    /// Gets the ERC20 address for a single offer.
    fn erc20_address(self: @TContractState) -> ContractAddress;

    /// Gets the price for a single offer.
    fn price(self: @TContractState) -> u256;
}

/// Interface for multiple direct offers.
#[starknet::interface]
trait IDirectMultiple<TContractState> {
    /// Purchases a multiple offer.
    fn purchase(ref self: TContractState, offer_hash: felt252, ask_hash: felt252);

    /// Sets the ask for a multiple offer.
    fn set_ask(ref self: TContractState, ask: Array<ERC20Amount>);

    /// Gets the ask hash for a multiple offer.
    fn ask_hash(self: @TContractState) -> felt252;

    /// Gets the ask for a multiple offer.
    fn ask(self: @TContractState) -> Array<ERC20Amount>;

    /// Gets the ask and hash for a multiple offer.
    fn ask_and_hash(self: @TContractState) -> (Array<ERC20Amount>, felt252);
}

/// Interface for one-of direct offers.
#[starknet::interface]
trait IDirectOneOf<TContractState> {
    /// Purchases a one-of offer.
    fn purchase(
        ref self: TContractState, offer_hash: felt252, erc20_address: ContractAddress, price: u256,
    );

    /// Sets the price for a one-of offer.
    fn set_price(ref self: TContractState, erc20_address: ContractAddress, price: u256);

    /// Removes a token from a one-of offer.
    fn remove_token(ref self: TContractState, erc20_address: ContractAddress);

    /// Gets the price for a one-of offer.
    fn price(self: @TContractState, erc20_address: ContractAddress) -> u256;
}

/// Core interface for direct contracts.
#[starknet::interface]
trait IDirectCore<TContractState> {
    /// Pauses the contract.
    fn pause(ref self: TContractState);

    /// Resumes the contract.
    fn resume(ref self: TContractState);

    /// Closes the contract.
    fn close(ref self: TContractState);

    /// Modifies the offer.
    fn modify_offer(
        ref self: TContractState, new_offer: Array<Token>, add: Array<Token>, remove: Array<Token>,
    );

    /// Modifies the expiry.
    fn modify_expiry(ref self: TContractState, expiry: u64);

    /// Gets the offer.
    fn offer(self: @TContractState) -> Array<Token>;

    /// Gets the expiry.
    fn expiry(self: @TContractState) -> u64;

    /// Gets the seller.
    fn seller(self: @TContractState) -> ContractAddress;

    /// Gets the offer hash.
    fn offer_hash(self: @TContractState) -> felt252;

    /// Gets the offer and hash.
    fn offer_and_hash(self: @TContractState) -> (Array<Token>, felt252);

    /// Verifies the offer.
    fn verify_offer(self: @TContractState) -> bool;
}

