use core::poseidon::{poseidon_hash_span};
use starknet::{
    ContractAddress, get_contract_address,
    storage_access::{StorageBaseAddress, storage_base_address_from_felt252},
};
use market::storage::{
    storage_read, storage_read_value, storage_write, storage_write_value,
    storage_read_from_base_offset, storage_write_from_base_offset,
    storage_read_value_from_base_offset, storage_write_value_from_base_offset,
};

use openzeppelin_token::{
    erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait},
    erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait},
};

#[derive(Drop, Serde, Introspect)]
struct ERC20Amount {
    contract_address: ContractAddress,
    amount: u256,
}

#[derive(Drop, Serde, Introspect)]
struct ERC721Token {
    contract_address: ContractAddress,
    token_id: u256,
}

#[derive(Drop, Serde, Introspect)]
struct ERC721Tokens {
    contract_address: ContractAddress,
    token_ids: Array<u256>,
}

#[derive(Drop, Serde, Introspect)]
enum Token {
    ERC20: ERC20Amount,
    ERC721: ERC721Token,
    ERC721s: ERC721Tokens,
}


trait StoreTokenTrait<T> {
    fn read_token(base_address: StorageBaseAddress, offset: u8) -> T;
    fn write_token(self: T, base_address: StorageBaseAddress, offset: u8);
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


fn read_goods(address: felt252) -> Array<Token> {
    let mut tokens = ArrayTrait::<Token>::new();
    for n in 0_u32..storage_read_value(address.try_into().unwrap()) {
        tokens
            .append(
                StoreTokenTrait::read_token(
                    storage_base_address_from_felt252(
                        poseidon_hash_span([LOT_ADDRESS_FELT252, n.into()].span()),
                    ),
                    0,
                ),
            );
    };
    tokens
}

fn write_goods(address: felt252, tokens: Array<Token>) {
    let len = tokens.len();
    storage_write_value(address.try_into().unwrap(), len);
    for n in 0..len {
        StoreTokenTrait::write_token(
            *tokens.at(n),
            storage_base_address_from_felt252(poseidon_hash_span([LOT_ADDRESS_FELT252, n].span())),
            0,
        );
    };
}

#[generate_trait]
impl GetEnumValueImpl of GetEnumValueTrait {
    fn get_enum_value(self: @Token) -> u32 {
        match self {
            Token::ERC20(_) => 0,
            Token::ERC721(_) => 1,
            Token::ERC721s(_) => 2,
        }
    }
}


trait DispatcherTrait<T> {
    type Dispatcher;
    fn get_dispatcher(self: @T) -> Self::Dispatcher;
}

impl ERC20DispatcherImpl of DispatcherTrait<ERC20Amount> {
    type Dispatcher = ERC20ABIDispatcher;
    fn get_dispatcher(self: @ERC20Amount) -> ERC20ABIDispatcher {
        ERC20ABIDispatcher { contract_address: *self.contract_address }
    }
}

impl ERC721DispatcherImpl of DispatcherTrait<ERC721Token> {
    type Dispatcher = ERC721ABIDispatcher;
    fn get_dispatcher(self: @ERC721Token) -> ERC721ABIDispatcher {
        ERC721ABIDispatcher { contract_address: *self.contract_address }
    }
}

impl ERC721sDispatcherImpl of DispatcherTrait<ERC721Tokens> {
    type Dispatcher = ERC721ABIDispatcher;
    fn get_dispatcher(self: @ERC721Tokens) -> ERC721ABIDispatcher {
        ERC721ABIDispatcher { contract_address: *self.contract_address }
    }
}

fn check_erc20_allowed(
    dispatcher: ERC20ABIDispatcher, owner: ContractAddress, spender: ContractAddress, amount: u256,
) -> bool {
    (dispatcher.balance_of(owner) >= amount) && (dispatcher.allowance(owner, spender) >= amount)
}

fn check_erc721_allowed(
    dispatcher: ERC721ABIDispatcher,
    owner: ContractAddress,
    operator: ContractAddress,
    token_id: u256,
) -> bool {
    (dispatcher.owner_of(token_id) == owner)
        && (dispatcher.is_approved_for_all(owner, operator)
            || (operator == dispatcher.get_approved(token_id)))
}
trait TokenTrait<T> {
    fn is_allowed(self: @T, owner: ContractAddress, operator: ContractAddress) -> bool;
    fn check_allowed(
        self: @T, owner: ContractAddress, operator: ContractAddress,
    ) {
        assert(Self::is_allowed(self, owner, operator), 'Not Allowed');
    }
    fn transfer(self: T, to: ContractAddress);
    fn transfer_from(self: T, from: ContractAddress, to: ContractAddress);
}

impl ERC20TokenImpl of TokenTrait<ERC20Amount> {
    fn is_allowed(self: @ERC20Amount, owner: ContractAddress, operator: ContractAddress) -> bool {
        check_erc20_allowed(self.get_dispatcher(), owner, operator, *self.amount)
    }
    fn transfer(self: ERC20Amount, to: ContractAddress) {
        self.get_dispatcher().transfer(to, self.amount);
    }
    fn transfer_from(self: ERC20Amount, from: ContractAddress, to: ContractAddress) {
        self.get_dispatcher().transfer_from(from, to, self.amount);
    }
}

impl ERC721TokenImpl of TokenTrait<ERC721Token> {
    fn is_allowed(self: @ERC721Token, owner: ContractAddress, operator: ContractAddress) -> bool {
        check_erc721_allowed(self.get_dispatcher(), owner, operator, *self.token_id)
    }
    fn transfer(self: ERC721Token, to: ContractAddress) {
        Self::transfer_from(self, get_contract_address(), to);
    }
    fn transfer_from(self: ERC721Token, from: ContractAddress, to: ContractAddress) {
        self.get_dispatcher().transfer_from(from, to, self.token_id);
    }
}

impl ERC721sTokenImpl of TokenTrait<ERC721Tokens> {
    fn is_allowed(self: @ERC721Tokens, owner: ContractAddress, operator: ContractAddress) -> bool {
        let dispatcher = self.get_dispatcher();
        let mut token_ids = self.token_ids.span();
        loop {
            match token_ids.pop_front() {
                Option::Some(token_id) => {
                    if !check_erc721_allowed(dispatcher, owner, operator, *token_id) {
                        break false;
                    }
                },
                Option::None => { break true; },
            }
        }
    }
    fn transfer(self: ERC721Tokens, to: ContractAddress) {
        Self::transfer_from(self, get_contract_address(), to);
    }
    fn transfer_from(self: ERC721Tokens, from: ContractAddress, to: ContractAddress) {
        let dispatcher = self.get_dispatcher();
        for token_id in self.token_ids {
            dispatcher.transfer_from(from, to, token_id);
        }
    }
}

impl EnumTokenImpl of TokenTrait<Token> {
    fn is_allowed(self: @Token, owner: ContractAddress, operator: ContractAddress) -> bool {
        match self {
            Token::ERC20(token) => token.is_allowed(owner, operator),
            Token::ERC721(token) => token.is_allowed(owner, operator),
            Token::ERC721s(tokens) => tokens.is_allowed(owner, operator),
        }
    }

    fn transfer(self: Token, to: ContractAddress) {
        match self {
            Token::ERC20(token) => token.transfer(to),
            Token::ERC721(token) => token.transfer(to),
            Token::ERC721s(tokens) => tokens.transfer(to),
        }
    }

    fn transfer_from(self: Token, from: ContractAddress, to: ContractAddress) {
        match self {
            Token::ERC20(token) => token.transfer_from(from, to),
            Token::ERC721(token) => token.transfer_from(from, to),
            Token::ERC721s(tokens) => tokens.transfer_from(from, to),
        }
    }
}


impl TokenArrayTokenImpl of TokenTrait<Array<Token>> {
    fn is_allowed(self: @Array<Token>, owner: ContractAddress, operator: ContractAddress) -> bool {
        let mut tokens = self.span();
        loop {
            match tokens.pop_front() {
                Option::Some(token) => { if !token.is_allowed(owner, operator) {
                    break false;
                } },
                Option::None => { break true; },
            }
        }
    }

    fn transfer(self: Array<Token>, to: ContractAddress) {
        for token in self {
            token.transfer(to);
        }
    }

    fn transfer_from(self: Array<Token>, from: ContractAddress, to: ContractAddress) {
        for token in self {
            token.transfer_from(from, to);
        }
    }
}


impl ERC20AmountArrayTokenImpl of TokenTrait<Array<ERC20Amount>> {
    fn is_allowed(
        self: @Array<ERC20Amount>, owner: ContractAddress, operator: ContractAddress,
    ) -> bool {
        let mut tokens = self.span();
        loop {
            match tokens.pop_front() {
                Option::Some(token) => { if !token.is_allowed(owner, operator) {
                    break false;
                } },
                Option::None => { break true; },
            }
        }
    }
    fn transfer(self: Array<ERC20Amount>, to: ContractAddress) {
        for token in self {
            token.transfer(to);
        }
    }

    fn transfer_from(self: Array<ERC20Amount>, from: ContractAddress, to: ContractAddress) {
        for token in self {
            token.transfer_from(from, to);
        }
    }
}

