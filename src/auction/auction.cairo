use starknet::ContractAddress;
use market::token::Token;

#[starknet::interface]
trait IAuction<TState> {
    fn bid(ref self: TState, amount: u256);
    fn complete(ref self: TState);
    fn rescind(ref self: TState);
    fn erc20_address(self: @TState) -> ContractAddress;
    fn highest_bid(self: @TState) -> u256;
    fn highest_bidder(self: @TState) -> ContractAddress;
    fn lot(self: @TState) -> Array<Token>;
    fn increment(self: @TState) -> u256;
    fn reserve(self: @TState) -> u256;
    fn expiry(self: @TState) -> u64;
    fn tax_ppm(self: @TState) -> u32;
    fn beneficiary(self: @TState) -> ContractAddress;
    fn open(self: @TState) -> bool;
    fn verify_lot_ownership(self: @TState) -> bool;
}

#[starknet::contract]
mod auction {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    use market::token::{Token, TokenTrait, StoreGoodsTrait};
    use market::tax::calc_tax;

    use super::IAuction;

    const GOODS_ADDRESS: felt252 = selector!("offer");

    #[storage]
    struct Storage {
        manager: ContractAddress,
        tax_ppm: u32,
        beneficiary: ContractAddress,
        seller: ContractAddress,
        expiry: u64,
        erc20_address: ContractAddress,
        reserve: u256,
        increment: u256,
        bidder: ContractAddress,
        bid: u256,
        closed: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        seller: ContractAddress,
        lot: Array<Token>,
        expiry: u64,
        reserve: u256,
        increment: u256,
    ) {
        self.manager.write(get_contract_address());
        self.beneficiary.write(beneficiary);
        self.tax_ppm.write(tax_ppm);
        self.seller.write(seller);
        self.expiry.write(expiry);
        self.reserve.write(reserve);
        self.increment.write(increment);
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn get_erc20_dispatcher(self: @ContractState) -> ERC20ABIDispatcher {
            ERC20ABIDispatcher { contract_address: self.erc20_address.read() }
        }

        fn assert_running(self: @ContractState) {
            self.assert_open();
            assert(get_block_timestamp() <= self.expiry.read(), 'Auction has expired');
        }

        fn assert_open(self: @ContractState) {
            assert(!self.closed.read(), 'Auction is closed');
        }

        fn transfer_lot(ref self: ContractState, to: ContractAddress) {
            self.lot().transfer(to);
            self.closed.write(true);
        }
    }

    #[abi(embed_v0)]
    impl IAuctionImpl of IAuction<ContractState> {
        fn bid(ref self: ContractState, amount: u256) {
            // Check that the auction is still open.
            self.assert_running();

            let current_bid = self.bid.read();
            let dispatcher = self.get_erc20_dispatcher();

            assert(amount >= current_bid + self.increment.read(), 'Bid below increment');

            if current_bid.is_zero() {
                // Check that the bid is above the reserve.
                assert(amount >= self.reserve.read(), 'Bid below reserve');
            } else {
                // Return the previous bid.
                dispatcher.transfer(self.bidder.read(), current_bid);
            }

            // Transfer the new bid.
            dispatcher.transfer_from(get_caller_address(), get_contract_address(), amount);
        }

        fn complete(ref self: ContractState) {
            self.assert_open();

            let seller = self.seller.read();
            let bid = self.bid.read();
            assert(bid.is_non_zero(), 'Reserve not met');

            if get_caller_address() != seller {
                assert(get_block_timestamp() > self.expiry.read(), 'Auction has not expired');
            }

            let dispatcher = self.get_erc20_dispatcher();

            let tax = split_tax(bid, self.tax_ppm.read());

            dispatcher.transfer(seller, bid - tax);
            dispatcher.transfer(self.emitter.read(), tax);

            self.transfer_lot(self.bidder.read());
        }

        fn rescind(ref self: ContractState) {
            self.assert_open();

            let seller = self.seller.read();
            assert(get_caller_address() == seller, 'Only the seller can rescind');

            self.transfer_lot(seller);
            self.get_erc20_dispatcher().transfer(self.bidder.read(), self.bid.read());
        }

        fn highest_bid(self: @ContractState) -> u256 {
            self.bid.read()
        }

        fn highest_bidder(self: @ContractState) -> ContractAddress {
            self.bidder.read()
        }

        fn lot(self: @ContractState) -> Array<Token> {
            StoreGoodsTrait::<Array<Token>>::read_goods(GOODS_ADDRESS)
        }

        fn increment(self: @ContractState) -> u256 {
            self.increment.read()
        }

        fn reserve(self: @ContractState) -> u256 {
            self.reserve.read()
        }

        fn expiry(self: @ContractState) -> u64 {
            self.expiry.read()
        }

        fn tax_ppm(self: @ContractState) -> u32 {
            self.tax_ppm.read()
        }

        fn open(self: @ContractState) -> bool {
            !self.closed.read()
        }

        fn verify_lot_ownership(self: @ContractState) -> bool {
            self.lot().is_owned(get_contract_address())
        }
    }
}
