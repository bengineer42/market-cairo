use super::interfaces;

#[starknet::contract]
mod direct_single {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use market::token::{Token, erc20_transfer_from};
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
        erc20_address: ContractAddress,
        price: u256,
        offer: Array<Token>,
        expiry: u64,
    ) {
        self.core.initializer(seller, offer, expiry);
        self.erc20_address.write(erc20_address);
        self.price.write(price);
    }

    #[abi(embed_v0)]
    impl IDirect = direct_component::DirectImpl<ContractState>;

    #[abi(embed_v0)]
    impl IDirectSingleImpl of IDirectSingle<ContractState> {
        fn purchase(ref self: ContractState, offer_hash: felt252, price: u256) {
            assert(price == self.price.read(), 'Price does not match');

            let caller = get_caller_address();
            erc20_transfer_from(self.erc20_address.read(), caller, self.core.seller(), price);

            self.core.assert_hash_and_transfer_goods(caller, offer_hash);
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
