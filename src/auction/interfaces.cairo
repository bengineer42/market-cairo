use starknet::ContractAddress;
use market::token::Token;
#[starknet::interface]
trait IAuctionManager<TState> {
    fn new_auction(
        ref self: TState, lot: Array<Token>, expiry: u64, reserve: u256, increment: u256,
    ) -> ContractAddress;
}

#[starknet::interface]
trait IAuctionEmitter<TState> {
    fn new_bid(ref self: TState, bid: u256, bidder: ContractAddress);
    fn auction_complete(ref self: TState, reserve_met: bool);
}
