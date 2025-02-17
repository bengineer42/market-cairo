use starknet::{ContractAddress, ClassHash};
use market::token::{Token, ERC20Amount};

#[starknet::interface]
trait IDirectManager<TContractState> {
    fn new_single(
        ref self: TContractState,
        offer: Array<Token>,
        erc20_address: ContractAddress,
        price: u256,
        expiry: u64,
    );
    fn new_multiple(
        ref self: TContractState, offer: Array<Token>, ask: Array<ERC20Amount>, expiry: u64,
    );
    fn new_one_of(
        ref self: TContractState,
        offer: Array<Token>,
        prices: Array<(ContractAddress, u256)>,
        expiry: u64,
    );

    fn set_single_class_hash(ref self: TContractState, class_hash: ClassHash);
    fn set_multiple_class_hash(ref self: TContractState, class_hash: ClassHash);
    fn set_one_of_class_hash(ref self: TContractState, class_hash: ClassHash);

    fn get_single_class_hash(self: @TContractState) -> ClassHash;
    fn get_multiple_class_hash(self: @TContractState) -> ClassHash;
    fn get_one_of_class_hash(self: @TContractState) -> ClassHash;

    fn emit_transfer(ref self: TContractState, to: ContractAddress);
    fn emit_close(ref self: TContractState);
    fn emit_new_expiry(ref self: TContractState, expiry: u64);
    fn emit_new_offer(ref self: TContractState, offer: Array<Token>, offer_hash: felt252);

    fn emit_single_new_price(ref self: TContractState, price: u256);
    fn emit_one_of_new_price(ref self: TContractState, erc20_address: ContractAddress, price: u256);
    fn emit_one_of_remove_token(ref self: TContractState, erc20_address: ContractAddress);
    fn emit_multiple_new_ask(ref self: TContractState, ask: Array<ERC20Amount>, ask_hash: felt252);

    fn tax(self: @TContractState) -> u32;
    fn set_tax(ref self: TContractState, ppm: u32);
}

#[starknet::interface]
trait IDirectSingle<TContractState> {
    fn purchase(ref self: TContractState, offer_hash: felt252, price: u256);
    fn set_price(ref self: TContractState, price: u256);
    fn erc20_address(self: @TContractState) -> ContractAddress;
    fn price(self: @TContractState) -> u256;
}

#[starknet::interface]
trait IDirectMultiple<TContractState> {
    fn purchase(ref self: TContractState, offer_hash: felt252, ask_hash: felt252);
    fn set_ask(ref self: TContractState, ask: Array<ERC20Amount>);

    fn ask_hash(self: @TContractState) -> felt252;
    fn ask(self: @TContractState) -> Array<ERC20Amount>;
    fn ask_and_hash(self: @TContractState) -> (Array<ERC20Amount>, felt252);
}

#[starknet::interface]
trait IDirectOneOf<TContractState> {
    fn purchase(
        ref self: TContractState, offer_hash: felt252, erc20_address: ContractAddress, price: u256,
    );
    fn set_price(ref self: TContractState, erc20_address: ContractAddress, price: u256);
    fn remove_token(ref self: TContractState, erc20_address: ContractAddress);
    fn price(self: @TContractState, erc20_address: ContractAddress) -> u256;
}


#[starknet::interface]
trait IDirect<TContractState> {
    fn pause(ref self: TContractState);
    fn resume(ref self: TContractState);
    fn close(ref self: TContractState);
    fn modify_offer(
        ref self: TContractState, new_offer: Array<Token>, add: Array<Token>, remove: Array<Token>,
    );
    fn modify_expiry(ref self: TContractState, expiry: u64);

    fn offer(self: @TContractState) -> Array<Token>;
    fn expiry(self: @TContractState) -> u64;
    fn seller(self: @TContractState) -> ContractAddress;
    fn offer_hash(self: @TContractState) -> felt252;
    fn offer_and_hash(self: @TContractState) -> (Array<Token>, felt252);
}

#[starknet::component]
mod direct_component {
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use market::{
        token::{Token, TokenTrait, StoreGoodsTrait, models::TokenArrayHashImpl},
        hash::HashValueTrait,
    };
    use super::IDirect;

    const GOODS_ADDRESS: felt252 = selector!("offer");

    #[storage]
    struct Storage {
        pub seller: ContractAddress,
        pub closed: bool,
        pub paused: bool,
        pub offer_hash: felt252,
        pub expiry: u64,
    }

    #[embeddable_as(DirectImpl)]
    impl IDirectImpl<
        TContractState, +HasComponent<TContractState>,
    > of IDirect<ComponentState<TContractState>> {
        fn pause(ref self: ComponentState<TContractState>) {
            self.assert_open();
            self.assert_caller_is_seller();
            assert(!self.paused.read(), 'Already Paused');
            self.paused.write(true);
        }

        fn resume(ref self: ComponentState<TContractState>) {
            self.assert_open();
            self.assert_not_paused();
            self.assert_caller_is_seller();
            self.paused.write(false);
        }

        fn close(ref self: ComponentState<TContractState>) {
            self.assert_open();
            self.transfer_goods(self.assert_caller_is_seller());
        }

        fn modify_offer(
            ref self: ComponentState<TContractState>,
            new_offer: Array<Token>,
            add: Array<Token>,
            remove: Array<Token>,
        ) {
            self.assert_open();

            let owner = self.assert_caller_is_seller();
            let this_address = get_contract_address();
            add.transfer_from(owner, this_address);
            remove.transfer(owner);
            let _new_offer = @new_offer;
            self.set_offer(new_offer);
            assert(_new_offer.is_owned(this_address), 'New Offer Incorrect');
        }

        fn modify_expiry(ref self: ComponentState<TContractState>, expiry: u64) {
            self.assert_open();
            self.assert_caller_is_seller();
            self.expiry.write(expiry);
        }

        fn offer(self: @ComponentState<TContractState>) -> Array<Token> {
            StoreGoodsTrait::<Array<Token>>::read_goods(GOODS_ADDRESS)
        }
        fn expiry(self: @ComponentState<TContractState>) -> u64 {
            self.expiry.read()
        }
        fn seller(self: @ComponentState<TContractState>) -> ContractAddress {
            self.seller.read()
        }
        fn offer_hash(self: @ComponentState<TContractState>) -> felt252 {
            self.offer_hash.read()
        }
        fn offer_and_hash(self: @ComponentState<TContractState>) -> (Array<Token>, felt252) {
            (self.offer(), self.offer_hash())
        }
    }

    #[generate_trait]
    impl DirectCoreImpl<
        TContractState, +HasComponent<TContractState>,
    > of DirectCoreTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            seller: ContractAddress,
            offer: Array<Token>,
            expiry: u64,
        ) {
            self.seller.write(seller);
            self.expiry.write(expiry);
            self.set_offer(offer);
        }

        fn transfer_goods(ref self: ComponentState<TContractState>, to: ContractAddress) {
            StoreGoodsTrait::<Array<Token>>::read_goods(GOODS_ADDRESS).transfer(to);
            self.closed.write(true);
        }

        fn assert_running(self: @ComponentState<TContractState>) {
            self.assert_open();
            self.assert_live();
            self.assert_not_paused();
        }

        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.paused.read(), 'Paused');
        }

        fn assert_open(self: @ComponentState<TContractState>) {
            assert(!self.closed.read(), 'Closed');
        }

        fn assert_live(self: @ComponentState<TContractState>) {
            assert(self.check_live(), 'Expired');
        }

        fn check_live(self: @ComponentState<TContractState>) -> bool {
            self.expiry.read() > get_block_timestamp()
        }

        fn set_offer(ref self: ComponentState<TContractState>, offer: Array<Token>) {
            self.offer_hash.write(offer.hash_value());
            offer.write_goods(GOODS_ADDRESS);
        }

        fn check_offer_hash(self: @ComponentState<TContractState>, hash: felt252) -> bool {
            self.offer_hash.read() == hash
        }

        fn assert_offer_hash(self: @ComponentState<TContractState>, hash: felt252) {
            assert(self.check_offer_hash(hash), 'Offer hash does not match');
        }

        fn assert_caller_is_seller(self: @ComponentState<TContractState>) -> ContractAddress {
            let seller = self.seller.read();
            assert(get_caller_address() == seller, 'Not Seller');
            seller
        }

        fn assert_hash_and_transfer_goods(
            ref self: ComponentState<TContractState>, to: ContractAddress, offer_hash: felt252,
        ) {
            self.assert_running();
            self.assert_offer_hash(offer_hash);
            self.transfer_goods(to);
        }
    }
}
