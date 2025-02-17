use super::interfaces;

#[starknet::contract]
mod direct {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use market::token::{Token, StoreGoodsTrait, ERC20Amount, TokenTrait, models::ArrayHashImpl};
    use market::hash::HashValueTrait;
    use super::interfaces::{direct_component, IDirectMultiple};
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
        ask: Array<ERC20Amount>,
        offer: Array<Token>,
        expiry: u64,
    ) {
        self.core.initializer(seller, offer, expiry);
        self.write_ask(ask);
    }

    #[abi(embed_v0)]
    impl IDirect = direct_component::DirectImpl<ContractState>;

    #[abi(embed_v0)]
    impl IDirectMultipleImpl of IDirectMultiple<ContractState> {
        fn purchase(ref self: ContractState, offer_hash: felt252, ask_hash: felt252) {
            assert(self.ask_hash.read() == ask_hash, 'Ask hash does not match');

            let caller = get_caller_address();
            self.read_ask().transfer_from(caller, self.core.seller());

            self.core.assert_hash_and_transfer_goods(caller, offer_hash);
        }

        fn set_ask(ref self: ContractState, ask: Array<ERC20Amount>) {
            self.core.assert_caller_is_seller();
            self.write_ask(ask);
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

        fn write_ask(ref self: ContractState, ask: Array<ERC20Amount>) {
            self.ask_hash.write(ask.hash_value());
            ask.write_goods(ASK_ADDRESS);
        }
    }
}
