use core::poseidon::poseidon_hash_span;
use starknet::{
    ContractAddress, StorageBaseAddress, storage_access::storage_base_address_from_felt252,
};
use market::storage::{
    storage_read_value, storage_write_value, storage_read_value_from_base_offset,
    storage_write_value_from_base_offset,
};
use super::{Token, ERC20Amount, ERC721Token, ERC721Tokens, GetEnumValueTrait};

trait StoreTokenTrait<T> {
    fn read_token(base_address: StorageBaseAddress, offset: u8) -> T;
    fn write_token(self: T, base_address: StorageBaseAddress, offset: u8);
}

trait StoreGoodsTrait<T> {
    fn read_goods(address: felt252) -> T;
    fn write_goods(self: T, address: felt252);
}

fn read_contract_address_u256(
    base_address: StorageBaseAddress, offset: u8,
) -> (ContractAddress, u256) {
    let contract_address = storage_read_value_from_base_offset(base_address, offset);
    let low = storage_read_value_from_base_offset(base_address, offset + 1);
    let high = storage_read_value_from_base_offset(base_address, offset + 2);
    (contract_address, u256 { low, high })
}

fn write_contract_address_u256(
    base_address: StorageBaseAddress, offset: u8, contract_address: ContractAddress, value: u256,
) {
    storage_write_value_from_base_offset(base_address, offset, contract_address);
    storage_write_value_from_base_offset(base_address, offset + 1, value.low);
    storage_write_value_from_base_offset(base_address, offset + 2, value.high);
}

impl ERC20AmountStoreImpl of StoreTokenTrait<ERC20Amount> {
    fn read_token(base_address: StorageBaseAddress, offset: u8) -> ERC20Amount {
        let (contract_address, amount) = read_contract_address_u256(base_address, offset);
        ERC20Amount { contract_address, amount }
    }
    fn write_token(self: ERC20Amount, base_address: StorageBaseAddress, offset: u8) {
        write_contract_address_u256(base_address, offset, self.contract_address, self.amount);
    }
}

impl ERC721TokenStoreImpl of StoreTokenTrait<ERC721Token> {
    fn read_token(base_address: StorageBaseAddress, offset: u8) -> ERC721Token {
        let (contract_address, token_id) = read_contract_address_u256(base_address, offset);
        ERC721Token { contract_address, token_id }
    }
    fn write_token(self: ERC721Token, base_address: StorageBaseAddress, offset: u8) {
        write_contract_address_u256(base_address, offset, self.contract_address, self.token_id);
    }
}

impl ERC721TokensStoreImpl of StoreTokenTrait<ERC721Tokens> {
    fn read_token(base_address: StorageBaseAddress, offset: u8) -> ERC721Tokens {
        let contract_address: ContractAddress = storage_read_value_from_base_offset(
            base_address, 1,
        );
        let n_tokens: u8 = storage_read_value_from_base_offset(base_address, 2);
        let mut token_ids = ArrayTrait::<u256>::new();
        for n in 0..n_tokens {
            let m = (2 * n) + 3;
            let low: u128 = storage_read_value_from_base_offset(base_address, m);
            let high: u128 = storage_read_value_from_base_offset(base_address, m + 1);
            token_ids.append(u256 { low, high });
        };
        ERC721Tokens { contract_address, token_ids }
    }

    fn write_token(mut self: ERC721Tokens, base_address: StorageBaseAddress, offset: u8) {
        storage_write_value_from_base_offset(base_address, offset, self.contract_address);
        storage_write_value_from_base_offset(base_address, offset + 1, self.token_ids.len());
        let mut n = offset + 2;
        loop {
            match self.token_ids.pop_front() {
                Option::Some(token_id) => {
                    storage_write_value_from_base_offset(base_address, n, token_id.low);
                    storage_write_value_from_base_offset(base_address, n + 1, token_id.high);
                    n += 2;
                },
                Option::None => { break; },
            }
        };
    }
}

impl TokenEnumStoreImpl of StoreTokenTrait<Token> {
    fn read_token(base_address: StorageBaseAddress, offset: u8) -> Token {
        let token_type: u32 = storage_read_value_from_base_offset(base_address, offset);
        match token_type {
            0 => Token::ERC20(StoreTokenTrait::read_token(base_address, offset + 1)),
            1 => Token::ERC721(StoreTokenTrait::read_token(base_address, offset + 1)),
            2 => Token::ERC721s(StoreTokenTrait::read_token(base_address, offset + 1)),
            _ => { panic!("Invalid token type") },
        }
    }

    fn write_token(self: Token, base_address: StorageBaseAddress, offset: u8) {
        storage_write_value_from_base_offset(base_address, 0, self.get_enum_value());
        match self {
            Token::ERC20(token) => token.write_token(base_address, offset + 1),
            Token::ERC721(token) => token.write_token(base_address, offset + 1),
            Token::ERC721s(token) => token.write_token(base_address, offset + 1),
        }
    }
}

impl StoreArrayTokenImpl<T, +StoreTokenTrait<T>, +Drop<T>> of StoreGoodsTrait<Array<T>> {
    fn read_goods(address: felt252) -> Array<T> {
        let mut tokens = ArrayTrait::<T>::new();
        for n in 0_u32..storage_read_value(address.try_into().unwrap()) {
            tokens
                .append(
                    StoreTokenTrait::read_token(
                        storage_base_address_from_felt252(
                            poseidon_hash_span([address, n.into()].span()),
                        ),
                        0,
                    ),
                );
        };
        tokens
    }

    fn write_goods(mut self: Array<T>, address: felt252) {
        storage_write_value(address.try_into().unwrap(), self.len());
        let mut n = 0;
        loop {
            match self.pop_front() {
                Option::Some(token) => {
                    StoreTokenTrait::write_token(
                        token,
                        storage_base_address_from_felt252(poseidon_hash_span([address, n].span())),
                        0,
                    );
                    n += 1;
                },
                Option::None => { break; },
            }
        }
    }
}
// fn read_goods(address: felt252) -> Array<Token> {
//     let mut tokens = ArrayTrait::<Token>::new();
//     for n in 0_u32..storage_read_value(address.try_into().unwrap()) {
//         tokens
//             .append(
//                 StoreTokenTrait::read_token(
//                     storage_base_address_from_felt252(
//                         poseidon_hash_span([address, n.into()].span()),
//                     ),
//                     0,
//                 ),
//             );
//     };
//     tokens
// }

// fn write_goods(address: felt252, mut tokens: Array<Token>) {
//     storage_write_value(address.try_into().unwrap(), tokens.len());
//     let mut n = 0;
//     loop {
//         match tokens.pop_front() {
//             Option::Some(token) => {
//                 StoreTokenTrait::write_token(
//                     token,
//                     storage_base_address_from_felt252(poseidon_hash_span([address, n].span())),
//                     0,
//                 );
//                 n += 1;
//             },
//             Option::None => { break; },
//         }
//     }
// }

