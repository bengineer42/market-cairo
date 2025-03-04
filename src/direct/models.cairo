use starknet::ContractAddress;
use market::token::{Token, ERC20Amount};

pub const DIRECT_NAMESPACE_HASH: felt252 = bytearray_hash!("direct_market");

pub const DIRECT_SINGLE_SELECTOR: felt252 = selector_from_tag!("direct_market-DirectSingle");
pub const DIRECT_MULTIPLE_SELECTOR: felt252 = selector_from_tag!("direct_market-DirectMultiple");
pub const DIRECT_ONE_OF_SELECTOR: felt252 = selector_from_tag!("direct_market-DirectOneOf");
const _DOOPS: felt252 = selector_from_tag!("direct_market-DirectOneOfPrice");
pub const DIRECT_ONE_OF_PRICE_SELECTOR: felt252 = _DOOPS;

/// DirectSingle represents a single direct sale listing in the marketplace
///
/// # Arguments
/// * `id` - Contract address of the selling contract
/// * `seller` - Address of the seller who created this listing
/// * `offer` - Array of tokens being offered for sale
/// * `offer_hash` - Hash of the offer details for verification
/// * `guaranteed` - Whether the offer is owned by the selling contract (true) or the seller (false)
/// * `expiry` - Timestamp when this listing expires
/// * `erc20_address` - Address of the ERC20 token accepted as payment
/// * `price` - Price in the specified ERC20 token
/// * `beneficiary` - Address that will receive the tax from the sale
/// * `tax_ppm` - Tax rate in parts per million
/// * `buyer` - Address of the buyer if listing is purchased
/// * `paused` - Whether the listing is currently paused
/// * `closed` - Whether the listing has been closed/completed
#[dojo::model]
#[derive(Drop, Serde)]
struct DirectSingle {
    #[key]
    id: ContractAddress,
    seller: ContractAddress,
    offer: Span<Token>,
    offer_hash: felt252,
    guaranteed: bool,
    expiry: u64,
    erc20_address: ContractAddress,
    price: u256,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    buyer: ContractAddress,
    paused: bool,
    closed: bool,
}

/// Represents a direct multiple token trade listing in the marketplace
/// # Arguments
/// * `id` - Contract address of the selling contract
/// * `seller` - Address of the user creating the listing/selling the tokens
/// * `offer` - Array of tokens being offered for sale
/// * `offer_hash` - Hash of the offer tokens for verification
/// * `guaranteed` - Whether the offer is owned by the selling contract (true) or the seller (false)
/// * `expiry` - Unix timestamp when the listing expires
/// * `ask` - Array of ERC20 tokens and amounts requested in exchange
/// * `ask_hash` - Hash of the ask tokens for verification
/// * `beneficiary` - Address that will receive the proceeds of the sale
/// * `tax_ppm` -Address that will receive the tax from the sale
/// * `buyer` - Address of the user buying/accepting the trade
/// * `paused` - Whether the listing is currently paused
/// * `closed` - Whether the listing has been completed/closed
#[dojo::model]
#[derive(Drop, Serde)]
struct DirectMultiple {
    #[key]
    id: ContractAddress,
    seller: ContractAddress,
    offer: Span<Token>,
    offer_hash: felt252,
    guaranteed: bool,
    expiry: u64,
    ask: Span<ERC20Amount>,
    ask_hash: felt252,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    buyer: ContractAddress,
    paused: bool,
    closed: bool,
}


/// DirectOneOf represents a direct sale listing in the marketplace that can be paid for in one of
/// multiple different ERC20 tokens
///
/// # Arguments
/// * `id` - Contract address of the selling contract
/// * `seller` - Address of the seller who created this listing
/// * `offer` - Array of tokens being offered for sale
/// * `offer_hash` - Hash of the offer details for verification
/// * `guaranteed` - Whether the offer is owned by the selling contract (true) or the seller (false)
/// * `expiry` - Timestamp when this listing expires
/// * `beneficiary` - Address that will receive the tax from the sale
/// * `tax_ppm` - Tax rate in parts per million
/// * `buyer` - Address of the buyer if listing is purchased
/// * `paused` - Whether the listing is currently paused
/// * `closed` - Whether the listing has been closed/completed
#[dojo::model]
#[derive(Drop, Serde)]
struct DirectOneOf {
    #[key]
    id: ContractAddress,
    seller: ContractAddress,
    offer: Span<Token>,
    offer_hash: felt252,
    guaranteed: bool,
    expiry: u64,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    buyer: ContractAddress,
    paused: bool,
    closed: bool,
}


/// A model representing a direct one-of-price listing in the marketplace
/// This model maps a contract address to a specific token price
///
/// # Fields
///
/// * `id` - The primary key contract address identifying this price listing
/// * `token_address` - The contract address of the token being priced
/// * `prices` - The price value in u256 format
#[dojo::model]
#[derive(Drop, Serde)]
struct DirectOneOfPrice {
    #[key]
    id: ContractAddress,
    #[key]
    token_address: ContractAddress,
    prices: u256,
}
