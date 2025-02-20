use starknet::{
    ContractAddress, ClassHash, SyscallResultTrait, syscalls::deploy_syscall, get_tx_info,
};


pub fn deploy_unwrap(
    class_hash: ClassHash, salt: felt252, calldata: Span<felt252>,
) -> (ContractAddress, Span<felt252>) {
    deploy_syscall(class_hash, salt, calldata, false).expect('Failed to deploy contract')
}

pub fn deploy_no_return(
    class_hash: ClassHash, salt: felt252, calldata: Span<felt252>,
) -> ContractAddress {
    let (contract_address, _) = deploy_unwrap(class_hash, salt, calldata);
    contract_address
}

pub fn deploy_with_single_return(
    class_hash: ClassHash, salt: felt252, calldata: Span<felt252>,
) -> (ContractAddress, felt252) {
    let (contract_address, return_values) = deploy_unwrap(class_hash, salt, calldata);
    assert(return_values.len() == 1, 'Expected a single return value');
    (contract_address, *return_values.at(0))
}

pub fn deploy_with_double_return(
    class_hash: ClassHash, salt: felt252, calldata: Span<felt252>,
) -> (ContractAddress, felt252, felt252) {
    let (contract_address, return_values) = deploy_unwrap(class_hash, salt, calldata);
    assert(return_values.len() == 2, 'Expected a double return value');
    (contract_address, *return_values.at(0), *return_values.at(1))
}

pub fn get_origin_caller_address() -> ContractAddress {
    get_tx_info().unbox().account_contract_address
}

