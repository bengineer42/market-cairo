use starknet::ContractAddress;
use dojo::{world::WorldStorage, event::EventStorage};
use market::token::{Token, ERC20Amount};

#[dojo::event]
#[derive(Drop, Serde)]
struct NewDirect {
    #[key]
    id: ContractAddress,
    seller: ContractAddress,
    beneficiary: ContractAddress,
    tax_ppm: u32,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectExpiry {
    #[key]
    id: ContractAddress,
    expiry: u64,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectOffer {
    #[key]
    id: ContractAddress,
    offer: Span<Token>,
    offer_hash: felt252,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectPaused {
    #[key]
    id: ContractAddress,
    paused: bool,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectClosed {
    #[key]
    id: ContractAddress,
    closed: bool,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectBought {
    #[key]
    id: ContractAddress,
    buyer: ContractAddress,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectSingleTokenAddress {
    #[key]
    id: ContractAddress,
    token_address: ContractAddress,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectSinglePrice {
    #[key]
    id: ContractAddress,
    price: u256,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectMultipleAsk {
    #[key]
    id: ContractAddress,
    ask: Span<ERC20Amount>,
    ask_hash: felt252,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct DirectOneOfPrice {
    #[key]
    id: ContractAddress,
    #[key]
    token_address: ContractAddress,
    prices: u256,
}

#[generate_trait]
impl DirectEventsImpl of DirectEvents {
    fn emit_direct_new(
        mut self: WorldStorage,
        id: ContractAddress,
        seller: ContractAddress,
        offer: Span<Token>,
        offer_hash: felt252,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
    ) {
        self.emit_event(@NewDirect { id, seller, beneficiary, tax_ppm });
        self.emit_direct_expiry(id, expiry);
        self.emit_direct_offer(id, offer, offer_hash);
    }

    fn emit_direct_expiry(mut self: WorldStorage, id: ContractAddress, expiry: u64) {
        self.emit_event(@DirectExpiry { id, expiry });
    }

    fn emit_direct_offer(
        mut self: WorldStorage, id: ContractAddress, offer: Span<Token>, offer_hash: felt252,
    ) {
        self.emit_event(@DirectOffer { id, offer, offer_hash });
    }

    fn emit_direct_bought(mut self: WorldStorage, id: ContractAddress, buyer: ContractAddress) {
        self.emit_event(@DirectBought { id, buyer });
        self.emit_direct_closed(id);
    }

    fn emit_direct_paused(mut self: WorldStorage, id: ContractAddress, paused: bool) {
        self.emit_event(@DirectPaused { id, paused });
    }

    fn emit_direct_closed(mut self: WorldStorage, id: ContractAddress) {
        self.emit_event(@DirectClosed { id, closed: true });
    }

    fn emit_direct_single_token_address(
        mut self: WorldStorage, id: ContractAddress, token_address: ContractAddress,
    ) {
        self.emit_event(@DirectSingleTokenAddress { id, token_address });
    }

    fn emit_direct_single_price(mut self: WorldStorage, id: ContractAddress, price: u256) {
        self.emit_event(@DirectSinglePrice { id, price });
    }

    fn emit_direct_multiple_ask(
        mut self: WorldStorage, id: ContractAddress, ask: Span<ERC20Amount>, ask_hash: felt252,
    ) {
        self.emit_event(@DirectMultipleAsk { id, ask, ask_hash });
    }

    fn emit_direct_one_of_price(
        mut self: WorldStorage, id: ContractAddress, token_address: ContractAddress, prices: u256,
    ) {
        self.emit_event(@DirectOneOfPrice { id, token_address, prices });
    }
}
