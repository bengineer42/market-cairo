use core::poseidon::poseidon_hash_span;
use starknet::{ContractAddress, ClassHash};

use market::token::{Token, ERC20Amount};

use super::{
    DirectType, DirectTypeTrait, DIRECT_NAMESPACE_HASH, DIRECT_SINGLE_SELECTOR,
    DIRECT_MULTIPLE_SELECTOR, DIRECT_ONE_OF_SELECTOR, DIRECT_ONE_OF_PRICE_SELECTOR, get_namespace,
};

use dojo_beacon::{MicroEmitter, ResourceComponent, utils::poseidon_hash_value};


#[generate_trait]
impl DirectEventsImpl<
    TContractState, +Drop<TContractState>, +ResourceComponent<TContractState>,
> of DirectEvents<TContractState> {
    fn emit_setup(
        ref self: TContractState,
        direct_single_model_class_hash: ClassHash,
        direct_multiple_model_class_hash: ClassHash,
        direct_one_of_model_class_hash: ClassHash,
        direct_one_of_price_model_class_hash: ClassHash,
    ) {
        let namespace = get_namespace();

        self.register_namespace(namespace.clone(), DIRECT_NAMESPACE_HASH);
        self
            .register_model(
                namespace.clone(), DIRECT_NAMESPACE_HASH, direct_single_model_class_hash,
            );
        self
            .register_model(
                namespace.clone(), DIRECT_NAMESPACE_HASH, direct_multiple_model_class_hash,
            );
        self
            .register_model(
                namespace.clone(), DIRECT_NAMESPACE_HASH, direct_one_of_model_class_hash,
            );
        self
            .register_model(
                namespace.clone(), DIRECT_NAMESPACE_HASH, direct_one_of_price_model_class_hash,
            );
    }
    fn emit_new_single(
        ref self: TContractState,
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
    ) {
        let entity_id = id.into();
        self
            .set_record(
                DIRECT_SINGLE_SELECTOR,
                entity_id,
                @entity_id,
                @(
                    seller,
                    offer,
                    offer_hash,
                    guaranteed,
                    expiry,
                    erc20_address,
                    price,
                    beneficiary,
                    tax_ppm,
                    0_felt252,
                    false,
                    false,
                ),
            );
    }

    fn emit_new_multiple(
        ref self: TContractState,
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
    ) {
        let entity_id = id.into();
        self
            .set_record(
                DIRECT_MULTIPLE_SELECTOR,
                entity_id,
                @entity_id,
                @(
                    seller,
                    offer,
                    offer_hash,
                    guaranteed,
                    expiry,
                    ask,
                    ask_hash,
                    beneficiary,
                    tax_ppm,
                    0_felt252,
                    false,
                    false,
                ),
            );
    }

    fn emit_new_one_of(
        ref self: TContractState,
        id: ContractAddress,
        seller: ContractAddress,
        offer: Span<Token>,
        offer_hash: felt252,
        guaranteed: bool,
        expiry: u64,
        prices: Span<(ContractAddress, u256)>,
        beneficiary: ContractAddress,
        tax_ppm: u32,
    ) {
        let entity_id = id.into();
        self
            .set_record(
                DIRECT_ONE_OF_SELECTOR,
                entity_id,
                @entity_id,
                @(
                    seller,
                    offer,
                    offer_hash,
                    guaranteed,
                    expiry,
                    prices,
                    beneficiary,
                    tax_ppm,
                    0_felt252,
                    false,
                    false,
                ),
            );
    }


    fn emit_direct_type_member<T, +Serde<T>>(
        ref self: TContractState,
        direct_type: DirectType,
        id: ContractAddress,
        member_selector: felt252,
        value: @T,
    ) {
        self.update_member(direct_type.selector(), id.into(), member_selector, value);
    }

    fn emit_expiry(
        ref self: TContractState, direct_type: DirectType, id: ContractAddress, expiry: u64,
    ) {
        self.emit_direct_type_member(direct_type, id, selector!("expiry"), @expiry);
    }

    fn emit_offer(
        ref self: TContractState,
        direct_type: DirectType,
        id: ContractAddress,
        offer: Span<Token>,
        offer_hash: felt252,
    ) {
        self.emit_direct_type_member(direct_type, id, selector!("offer"), offer.into());
        self.emit_direct_type_member(direct_type, id, selector!("offer_hash"), @offer_hash);
    }

    fn emit_closed(ref self: TContractState, direct_type: DirectType, id: ContractAddress) {
        self.emit_direct_type_member(direct_type, id, selector!("closed"), @true);
    }

    fn emit_bought(
        ref self: TContractState,
        direct_type: DirectType,
        id: ContractAddress,
        buyer: ContractAddress,
    ) {
        self.emit_direct_type_member(direct_type, id, selector!("buyer"), @buyer);
        self.emit_closed(direct_type, id);
    }

    fn emit_paused(
        ref self: TContractState, direct_type: DirectType, id: ContractAddress, paused: bool,
    ) {
        self.emit_direct_type_member(direct_type, id, selector!("paused"), @paused);
    }

    fn emit_single_price(ref self: TContractState, id: ContractAddress, price: u256) {
        self.emit_direct_type_member(DirectType::Single, id, selector!("price"), @price);
    }

    fn emit_multiple_ask(
        ref self: TContractState, id: ContractAddress, ask: Span<ERC20Amount>, ask_hash: felt252,
    ) {
        self.emit_direct_type_member(DirectType::Multiple, id, selector!("ask"), ask.into());
        self.emit_direct_type_member(DirectType::Multiple, id, selector!("ask_hash"), @ask_hash);
    }
    fn emit_one_of_price(
        ref self: TContractState, id: ContractAddress, token_address: ContractAddress, price: u256,
    ) {
        let key = @(id, token_address);
        let entity_id = poseidon_hash_value(key);
        self.set_record(DIRECT_ONE_OF_PRICE_SELECTOR, entity_id, key, @price);
    }
}
