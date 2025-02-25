use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
use market::{
    token::{Token, TokenTrait, StoreGoodsTrait, models::TokenArrayHashImpl}, hash::HashValueTrait,
    tax::TransferAndTax,
};

use market::direct::interfaces::{
    IDirectCore, IDirectManagerDispatcher, IDirectManagerDispatcherTrait,
};
const GOODS_ADDRESS: felt252 = selector!("offer");

fn read_offer() -> Array<Token> {
    StoreGoodsTrait::<Array<Token>>::read_goods(GOODS_ADDRESS)
}

trait OfferTrait<TContractState> {
    fn modify_offer_transfer(
        ref self: ComponentState<TContractState>,
        new_offer: @Array<Token>,
        add: Array<Token>,
        remove: Array<Token>,
    );
    fn return_goods(ref self: ComponentState<TContractState>, seller: ContractAddress);
    fn transfer_goods_to(ref self: ComponentState<TContractState>, to: ContractAddress);
    fn verify_offer_ownership(self: @ComponentState<TContractState>) -> bool;
}
use direct_core_component::ComponentState;

trait DirectCoreTrait<TContractState> {
    fn initializer(
        ref self: ComponentState<TContractState>,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
    ) -> felt252;
    fn set_modified_offer(ref self: ComponentState<TContractState>, offer: Array<Token>);
    fn assert_running(self: @ComponentState<TContractState>);
    fn assert_not_paused(self: @ComponentState<TContractState>);
    fn assert_paused(self: @ComponentState<TContractState>);
    fn assert_open(self: @ComponentState<TContractState>);
    fn assert_live(self: @ComponentState<TContractState>);
    fn check_live(self: @ComponentState<TContractState>) -> bool;
    fn set_offer(ref self: ComponentState<TContractState>, offer: Array<Token>) -> felt252;
    fn check_offer_hash(self: @ComponentState<TContractState>, offer_hash: felt252) -> bool;
    fn assert_offer_hash(self: @ComponentState<TContractState>, offer_hash: felt252);
    fn assert_caller_is_seller(self: @ComponentState<TContractState>) -> ContractAddress;
    fn assert_hash_and_take_payment<T, +TransferAndTax<T>, +Drop<T>>(
        ref self: ComponentState<TContractState>,
        buyer: ContractAddress,
        offer_hash: felt252,
        payment: T,
    );
    fn manager_dispatcher(self: @ComponentState<TContractState>) -> IDirectManagerDispatcher;
}

#[starknet::component]
mod direct_core_component {
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use market::{
        token::{Token, TokenTrait, StoreGoodsTrait, models::TokenArrayHashImpl},
        hash::HashValueTrait, tax::TransferAndTax,
    };
    use market::direct::interfaces::{
        IDirectCore, IDirectManagerDispatcher, IDirectManagerDispatcherTrait,
    };
    use super::{GOODS_ADDRESS, read_offer, DirectCoreTrait};


    #[storage]
    struct Storage {
        pub seller: ContractAddress,
        pub closed: bool,
        pub paused: bool,
        pub offer_hash: felt252,
        pub expiry: u64,
        pub beneficiary: ContractAddress,
        pub tax_ppm: u32,
        pub manager: ContractAddress,
        pub guaranteed: bool,
    }

    #[embeddable_as(DirectImpl)]
    impl IDirectImpl<
        TContractState,
        impl Offer: super::OfferTrait<TContractState>,
        +HasComponent<TContractState>,
    > of IDirectCore<ComponentState<TContractState>> {
        fn pause(ref self: ComponentState<TContractState>) {
            self.assert_open();
            self.assert_caller_is_seller();
            self.assert_not_paused();
            assert(!self.paused.read(), 'Already Paused');
            self.paused.write(true);
            self.manager_dispatcher().set_paused();
        }

        fn resume(ref self: ComponentState<TContractState>) {
            self.assert_open();
            self.assert_caller_is_seller();
            self.assert_paused();
            self.paused.write(false);
            self.manager_dispatcher().set_resumed();
        }

        fn close(ref self: ComponentState<TContractState>) {
            self.assert_open();
            Offer::return_goods(ref self, self.assert_caller_is_seller());
            self.manager_dispatcher().set_closed();
        }

        fn modify_offer(
            ref self: ComponentState<TContractState>,
            new_offer: Array<Token>,
            add: Array<Token>,
            remove: Array<Token>,
        ) {
            self.assert_open();
            Offer::modify_offer_transfer(ref self, @new_offer, add, remove);
            let new_offer_span = new_offer.span();
            let offer_hash = self.set_offer(new_offer);
            self.manager_dispatcher().set_new_offer(new_offer_span, offer_hash);
        }

        fn modify_expiry(ref self: ComponentState<TContractState>, expiry: u64) {
            self.assert_open();
            self.assert_caller_is_seller();
            self.expiry.write(expiry);
        }

        fn expiry(self: @ComponentState<TContractState>) -> u64 {
            self.expiry.read()
        }
        fn seller(self: @ComponentState<TContractState>) -> ContractAddress {
            self.seller.read()
        }
        fn offer(self: @ComponentState<TContractState>) -> Array<Token> {
            read_offer()
        }
        fn offer_hash(self: @ComponentState<TContractState>) -> felt252 {
            self.offer_hash.read()
        }
        fn offer_and_hash(self: @ComponentState<TContractState>) -> (Array<Token>, felt252) {
            (read_offer(), Self::offer_hash(self))
        }
        fn verify_offer(self: @ComponentState<TContractState>) -> bool {
            Offer::verify_offer_ownership(self)
        }
    }

    impl DirectCoreImpl<
        TContractState, impl Offer: super::OfferTrait<TContractState>,
    > of DirectCoreTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            seller: ContractAddress,
            offer: Array<Token>,
            expiry: u64,
            beneficiary: ContractAddress,
            tax_ppm: u32,
        ) -> felt252 {
            self.seller.write(seller);
            self.expiry.write(expiry);
            self.beneficiary.write(beneficiary);
            self.tax_ppm.write(tax_ppm);
            self.manager.write(get_caller_address());
            self.set_offer(offer)
        }

        fn set_modified_offer(ref self: ComponentState<TContractState>, offer: Array<Token>) {
            let offer_span = offer.span();
            let offer_hash = self.set_offer(offer);
            self.manager_dispatcher().set_new_offer(offer_span, offer_hash);
        }

        fn assert_running(self: @ComponentState<TContractState>) {
            self.assert_open();
            self.assert_live();
            self.assert_not_paused();
        }

        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.paused.read(), 'Paused');
        }

        fn assert_paused(self: @ComponentState<TContractState>) {
            assert(self.paused.read(), 'Not Paused');
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

        fn set_offer(ref self: ComponentState<TContractState>, offer: Array<Token>) -> felt252 {
            let offer_hash = offer.hash_value();
            self.offer_hash.write(offer_hash);
            offer.write_goods(GOODS_ADDRESS);
            offer_hash
        }

        fn check_offer_hash(self: @ComponentState<TContractState>, offer_hash: felt252) -> bool {
            self.offer_hash.read() == offer_hash
        }

        fn assert_offer_hash(self: @ComponentState<TContractState>, offer_hash: felt252) {
            assert(self.check_offer_hash(offer_hash), 'Offer hash does not match');
        }

        fn assert_caller_is_seller(self: @ComponentState<TContractState>) -> ContractAddress {
            let seller = self.seller.read();
            assert(get_caller_address() == seller, 'Not Seller');
            seller
        }

        fn assert_hash_and_take_payment<T, +TransferAndTax<T>, +Drop<T>>(
            ref self: ComponentState<TContractState>,
            buyer: ContractAddress,
            offer_hash: felt252,
            payment: T,
        ) {
            self.assert_running();
            self.assert_offer_hash(offer_hash);
            payment
                .transfer_from_and_tax(
                    buyer, self.seller.read(), self.tax_ppm.read(), self.beneficiary.read(),
                );
            self.manager_dispatcher().set_bought(buyer);
            Offer::transfer_goods_to(ref self, buyer);
        }

        fn manager_dispatcher(self: @ComponentState<TContractState>) -> IDirectManagerDispatcher {
            IDirectManagerDispatcher { contract_address: self.manager.read() }
        }
    }
}

