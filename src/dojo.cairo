use starknet::{
    ContractAddress, SyscallResultTrait,
    storage_access::{storage_read_syscall, storage_address_from_base, storage_base_address_const},
};
use dojo::world::{IWorldDispatcher, WorldStorage};

const WORLD_STORAGE_LOCATION: felt252 =
    0x01704e5494cfadd87ce405d38a662ae6a1d354612ea0ebdc9fefdeb969065774;

fn get_world_address() -> ContractAddress {
    storage_read_syscall(
        0, storage_address_from_base(storage_base_address_const::<WORLD_STORAGE_LOCATION>()),
    )
        .unwrap_syscall()
        .try_into()
        .unwrap()
}

fn get_storage_from_hash(namespace_hash: felt252) -> WorldStorage {
    WorldStorage {
        dispatcher: IWorldDispatcher { contract_address: get_world_address() }, namespace_hash,
    }
}
