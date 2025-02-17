use super::interfaces;

#[starknet::contract]
mod direct_one_of {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use market::token::{Token, erc20_transfer_from};
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
        prices: Array<(ContractAddress, u256)>,
        offer: Array<Token>,
        expiry: u64,
    ) {
        self.core.initializer(seller, offer, expiry);
        for (erc20_address, price) in prices {
            self.prices.entry(erc20_address).write(price);
        };
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
            erc20_transfer_from(erc20_address, caller, self.core.seller(), price);
            self.core.assert_hash_and_transfer_goods(caller, offer_hash);
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
