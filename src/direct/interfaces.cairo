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
        tax_ppm: u32,
    );
    fn new_multiple(
        ref self: TContractState,
        offer: Array<Token>,
        ask: Array<ERC20Amount>,
        expiry: u64,
        tax_ppm: u32,
    );
    fn new_one_of(
        ref self: TContractState,
        offer: Array<Token>,
        prices: Array<(ContractAddress, u256)>,
        expiry: u64,
        tax_ppm: u32,
    );

    fn set_single_class_hash(ref self: TContractState, class_hash: ClassHash);
    fn set_multiple_class_hash(ref self: TContractState, class_hash: ClassHash);
    fn set_one_of_class_hash(ref self: TContractState, class_hash: ClassHash);

    fn get_single_class_hash(self: @TContractState) -> ClassHash;
    fn get_multiple_class_hash(self: @TContractState) -> ClassHash;
    fn get_one_of_class_hash(self: @TContractState) -> ClassHash;

    fn set_bought(ref self: TContractState, buyer: ContractAddress);
    fn set_paused(ref self: TContractState);
    fn set_resumed(ref self: TContractState);
    fn set_closed(ref self: TContractState);
    fn set_new_expiry(ref self: TContractState, expiry: u64);
    fn set_new_offer(ref self: TContractState, offer: Span<Token>, offer_hash: felt252);

    fn set_single_new_price(ref self: TContractState, price: u256);
    fn set_one_of_new_price(ref self: TContractState, erc20_address: ContractAddress, price: u256);
    fn set_one_of_remove_token(ref self: TContractState, erc20_address: ContractAddress);
    fn set_multiple_new_ask(ref self: TContractState, ask: Span<ERC20Amount>, ask_hash: felt252);

    fn grant_owner(ref self: TContractState, contract_address: ContractAddress);
    fn revoke_owner(ref self: TContractState, contract_address: ContractAddress);
    fn is_owner(self: @TContractState, contract_address: ContractAddress) -> bool;

    fn set_beneficiary(ref self: TContractState, beneficiary: ContractAddress);
    fn set_tax(ref self: TContractState, ppm: u32);
    fn beneficiary(self: @TContractState) -> ContractAddress;
    fn tax_ppm(self: @TContractState) -> u32;
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
    fn verify_offer_ownership(self: @TContractState) -> bool;
}

#[starknet::component]
mod direct_component {
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use market::{
        token::{Token, TokenTrait, StoreGoodsTrait, models::TokenArrayHashImpl},
        hash::HashValueTrait, tax::TransferAndTax,
    };
    use super::{IDirect, IDirectManagerDispatcher, IDirectManagerDispatcherTrait};

    const GOODS_ADDRESS: felt252 = selector!("offer");

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
            self.manager_dispatcher().set_paused();
        }

        fn resume(ref self: ComponentState<TContractState>) {
            self.assert_open();
            self.assert_not_paused();
            self.assert_caller_is_seller();
            self.paused.write(false);
            self.manager_dispatcher().set_resumed();
        }

        fn close(ref self: ComponentState<TContractState>) {
            self.assert_open();
            self.transfer_goods(self.assert_caller_is_seller());
            self.manager_dispatcher().set_closed();
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
            let offer_hash = self.set_offer(new_offer);
            assert(_new_offer.is_owned(this_address), 'New Offer Incorrect');
            self.manager_dispatcher().set_new_offer(_new_offer.span(), offer_hash);
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
        fn verify_offer_ownership(self: @ComponentState<TContractState>) -> bool {
            self.offer().is_owned(get_contract_address())
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

        fn assert_hash_and_transfer<T, +TransferAndTax<T>, +Drop<T>>(
            ref self: ComponentState<TContractState>,
            buyer: ContractAddress,
            offer_hash: felt252,
            payment: T,
        ) {
            self.assert_running();
            self.assert_offer_hash(offer_hash);
            self.transfer_goods(buyer);
            payment
                .transfer_from_and_tax(
                    buyer, self.seller(), self.tax_ppm.read(), self.beneficiary.read(),
                );
            self.manager_dispatcher().set_bought(buyer);
        }

        fn manager_dispatcher(self: @ComponentState<TContractState>) -> IDirectManagerDispatcher {
            IDirectManagerDispatcher { contract_address: self.manager.read() }
        }
    }
}
