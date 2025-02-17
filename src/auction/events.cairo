use starknet::ContractAddress;
use market::token::Token;

#[dojo::event]
#[derive(Drop, Serde)]
struct NewAuction {
    #[key]
    auction: ContractAddress,
    lot: Array<Token>,
    erc20_address: ContractAddress,
    reserve: u256,
    increment: u256,
    expiry: u64,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct NewBid {
    #[key]
    auction: ContractAddress,
    timestamp: u64,
    bid: u256,
    bidder: ContractAddress,
}

#[dojo::event]
#[derive(Drop, Serde)]
struct AuctionComplete {
    #[key]
    auction: ContractAddress,
    reserve_met: bool,
    expiry: u64,
}
