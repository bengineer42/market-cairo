use starknet::ContractAddress;
use market::token::{Token, ERC20Amount};

pub const DIRECT_NAMESPACE_HASH: felt252 = bytearray_hash!("direct_market");

pub const DIRECT_SINGLE_SELECTOR: felt252 = selector_from_tag!("direct_market-DirectSingle");
pub const DIRECT_MULTIPLE_SELECTOR: felt252 = selector_from_tag!("direct_market-DirectMultiple");
pub const DIRECT_ONE_OF_SELECTOR: felt252 = selector_from_tag!("direct_market-DirectOneOf");
const _DOOPS: felt252 = selector_from_tag!("direct_market-DirectOneOfPrice");
pub const DIRECT_ONE_OF_PRICE_SELECTOR: felt252 = _DOOPS;

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

#[dojo::model]
#[derive(Drop, Serde)]
struct DirectOneOfPrice {
    #[key]
    id: ContractAddress,
    #[key]
    token_address: ContractAddress,
    prices: u256,
}
