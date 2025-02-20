use starknet::{ContractAddress, ClassHash};
use market::{starknet::deploy_with_double_return, token::{Token, ERC20Amount}};
use super::interfaces;

pub fn deploy_direct_multiple(
    class_hash: ClassHash,
    salt: felt252,
    seller: ContractAddress,
    offer: Span<Token>,
    expiry: u64,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    ask: Span<ERC20Amount>,
) -> (ContractAddress, felt252, felt252) {
    let mut calldata: Array<felt252> = array![seller.into()];
    Serde::serialize(@offer, ref calldata);
    calldata.append_span([expiry.into(), beneficiary.into(), tax_ppm.into()].span());
    Serde::serialize(@ask, ref calldata);
    deploy_with_double_return(class_hash, salt, calldata.span())
}

#[starknet::contract]
mod direct_multiple {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use market::token::{Token, StoreGoodsTrait, ERC20Amount, TokenTrait, models::ArrayHashImpl};
    use market::hash::HashValueTrait;
    use super::interfaces::{direct_component, IDirectMultiple, IDirectManagerDispatcherTrait};
    use direct_component::DirectCoreTrait;

    component!(path: direct_component, storage: core, event: DirectEvent);

    const ASK_ADDRESS: felt252 = selector!("ask");

    #[storage]
    struct Storage {
        ask_hash: felt252,
        #[substorage(v0)]
        core: direct_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DirectEvent: direct_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        ask: Array<ERC20Amount>,
    ) -> (felt252, felt252) {
        let ask_hash = self.write_ask(ask);
        let offer_hash = self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm);
        (offer_hash, ask_hash)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_component::DirectImpl<ContractState>;

    #[abi(embed_v0)]
    impl IDirectMultipleImpl of IDirectMultiple<ContractState> {
        fn purchase(ref self: ContractState, offer_hash: felt252, ask_hash: felt252) {
            assert(self.ask_hash.read() == ask_hash, 'Ask hash does not match');

            let caller = get_caller_address();
            self.core.assert_hash_and_transfer(caller, offer_hash, self.read_ask());
        }

        fn set_ask(ref self: ContractState, ask: Array<ERC20Amount>) {
            self.core.assert_caller_is_seller();
            let ask_span = ask.span();
            let ask_hash = self.write_ask(ask);
            self.core.manager_dispatcher().set_multiple_new_ask(ask_span, ask_hash);
        }

        fn ask_hash(self: @ContractState) -> felt252 {
            self.ask_hash.read()
        }
        fn ask(self: @ContractState) -> Array<ERC20Amount> {
            self.read_ask()
        }
        fn ask_and_hash(self: @ContractState) -> (Array<ERC20Amount>, felt252) {
            (self.read_ask(), self.ask_hash.read())
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn read_ask(self: @ContractState) -> Array<ERC20Amount> {
            StoreGoodsTrait::read_goods(ASK_ADDRESS)
        }

        fn write_ask(ref self: ContractState, ask: Array<ERC20Amount>) -> felt252 {
            let ask_hash = ask.hash_value();
            self.ask_hash.write(ask_hash);
            ask.write_goods(ASK_ADDRESS);
            ask_hash
        }
    }
}
