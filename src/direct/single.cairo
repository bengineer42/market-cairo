use starknet::{ContractAddress, ClassHash};
use market::{starknet::deploy_with_single_return, token::Token};
use super::interfaces;

pub fn deploy_direct_single(
    class_hash: ClassHash,
    salt: felt252,
    seller: ContractAddress,
    offer: Span<Token>,
    expiry: u64,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    erc20_address: ContractAddress,
    price: u256,
) -> (ContractAddress, felt252) {
    let mut calldata: Array<felt252> = array![seller.into()];
    Serde::serialize(@offer, ref calldata);
    calldata
        .append_span(
            [
                expiry.into(), beneficiary.into(), tax_ppm.into(), erc20_address.into(),
                price.low.into(), price.high.into(),
            ]
                .span(),
        );
    deploy_with_single_return(class_hash, salt, calldata.span())
}

#[starknet::contract]
mod direct_single {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use market::token::Token;
    use super::interfaces::{direct_component, IDirectSingle};
    use direct_component::DirectCoreTrait;
    component!(path: direct_component, storage: core, event: DirectEvent);

    #[storage]
    struct Storage {
        erc20_address: ContractAddress,
        price: u256,
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
        erc20_address: ContractAddress,
        price: u256,
    ) -> felt252 {
        self.erc20_address.write(erc20_address);
        self.price.write(price);
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_component::DirectImpl<ContractState>;

    #[abi(embed_v0)]
    impl IDirectSingleImpl of IDirectSingle<ContractState> {
        fn purchase(ref self: ContractState, offer_hash: felt252, price: u256) {
            assert(price == self.price.read(), 'Price does not match');

            let caller = get_caller_address();
            self
                .core
                .assert_hash_and_transfer(caller, offer_hash, (self.erc20_address.read(), price));
        }

        fn set_price(ref self: ContractState, price: u256) {
            self.core.assert_open();
            self.core.assert_caller_is_seller();
            self.price.write(price);
        }

        fn price(self: @ContractState) -> u256 {
            self.price.read()
        }

        fn erc20_address(self: @ContractState) -> ContractAddress {
            self.erc20_address.read()
        }
    }
}
