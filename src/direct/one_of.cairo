use starknet::{ContractAddress, ClassHash};
use market::{starknet::deploy_with_single_return, token::Token};
use super::interfaces;

pub fn deploy_direct_one_of(
    class_hash: ClassHash,
    salt: felt252,
    seller: ContractAddress,
    offer: Span<Token>,
    expiry: u64,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    prices: Span<(ContractAddress, u256)>,
) -> (ContractAddress, felt252) {
    let mut calldata: Array<felt252> = array![seller.into()];
    Serde::serialize(@offer, ref calldata);
    calldata.append_span([expiry.into(), beneficiary.into(), tax_ppm.into()].span());
    Serde::serialize(@prices, ref calldata);
    deploy_with_single_return(class_hash, salt, calldata.span())
}

#[starknet::contract]
mod direct_one_of {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use market::token::Token;
    use super::interfaces::{direct_component, IDirectOneOf};
    use direct_component::DirectCoreTrait;
    component!(path: direct_component, storage: core, event: DirectEvent);

    #[storage]
    struct Storage {
        prices: Map<ContractAddress, u256>,
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
        prices: Array<(ContractAddress, u256)>,
    ) -> felt252 {
        for (erc20_address, price) in prices {
            self.prices.entry(erc20_address).write(price);
        };
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_component::DirectImpl<ContractState>;

    #[abi(embed_v0)]
    impl IDirectSingleImpl of IDirectOneOf<ContractState> {
        fn purchase(
            ref self: ContractState,
            offer_hash: felt252,
            erc20_address: ContractAddress,
            price: u256,
        ) {
            assert(price.is_non_zero(), 'ERC20 not useable');
            assert(price == self.prices.entry(erc20_address).read(), 'Price does not match');

            let caller = get_caller_address();
            self.core.assert_hash_and_transfer(caller, offer_hash, (erc20_address, price));
        }

        fn set_price(ref self: ContractState, erc20_address: ContractAddress, price: u256) {
            self.core.assert_caller_is_seller();
            self.prices.entry(erc20_address).write(price);
        }

        fn remove_token(ref self: ContractState, erc20_address: ContractAddress) {
            self.set_price(erc20_address, 0);
        }

        fn price(self: @ContractState, erc20_address: ContractAddress) -> u256 {
            self.prices.entry(erc20_address).read()
        }
    }
}
