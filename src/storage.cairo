use starknet::{
    ContractAddress, get_contract_address, StorageAddress, SyscallResultTrait,
    storage_access::{
        storage_address_from_base_and_offset, StorageBaseAddress, storage_read_syscall,
        storage_write_syscall,
    },
};

fn storage_read(address: StorageAddress) -> felt252 {
    storage_read_syscall(0, address).unwrap_syscall()
}

fn storage_write(address: StorageAddress, value: felt252) {
    storage_write_syscall(0, address, value).unwrap_syscall()
}

fn storage_read_value<T, +TryInto<felt252, T>>(address: StorageAddress) -> T {
    storage_read(address).try_into().unwrap()
}

fn storage_write_value<T, +Into<T, felt252>>(address: StorageAddress, value: T) {
    storage_write(address, value.into())
}

fn storage_read_from_base_offset(address: StorageBaseAddress, offset: u8) -> felt252 {
    storage_read(storage_address_from_base_and_offset(address, offset))
}

fn storage_write_from_base_offset(address: StorageBaseAddress, offset: u8, value: felt252) {
    storage_write(storage_address_from_base_and_offset(address, offset), value)
}

fn storage_read_value_from_base_offset<T, +TryInto<felt252, T>>(
    address: StorageBaseAddress, offset: u8,
) -> T {
    storage_read_from_base_offset(address, offset).try_into().unwrap()
}

fn storage_write_value_from_base_offset<T, +Into<T, felt252>>(
    address: StorageBaseAddress, offset: u8, value: T,
) {
    storage_write_from_base_offset(address, offset, value.into())
}
// fn storage_write_from_base_offsets(address: StorageBaseAddress, start: u8, stop: u8, values:
// Array<felt252>) {

// }


