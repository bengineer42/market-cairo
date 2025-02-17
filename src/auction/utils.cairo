use starknet::{ContractAddress, ClassHash, deploy_syscall, SyscallResultTrait};
use market::token::Token;
fn deploy_auction(
    class_hash: ClassHash,
    salt: felt252,
    emitter: ContractAddress,
    house: ContractAddress,
    tax_ppm: u32,
    seller: ContractAddress,
    lot: Span<Token>,
    expiry: u64,
    reserve: u256,
    increment: u256,
) -> ContractAddress {
    let mut calldata = array![emitter.into(), house.into(), tax_ppm.into(), seller.into()];
    Serde::serialize(lot.snapshot, ref calldata);
    calldata
        .append_span(
            [
                expiry.into(), reserve.low.into(), reserve.high.into(), increment.low.into(),
                increment.high.into(),
            ]
                .span(),
        );
    let (address, _) = deploy_syscall(class_hash, salt, calldata.span(), false).unwrap_syscall();
    address
}
