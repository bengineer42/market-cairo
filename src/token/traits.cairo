use core::poseidon::poseidon_hash_span;
use starknet::{ContractAddress, get_contract_address};
use openzeppelin_token::{
    erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait},
    erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait},
};

use super::{ERC20Amount, ERC721Token, ERC721Tokens, Token, GetEnumValueTrait, StoreGoodsTrait};

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
    fn is_owned(self: @T, owner: ContractAddress) -> bool;
    fn transfer(self: T, to: ContractAddress);
    fn transfer_from(self: T, from: ContractAddress, to: ContractAddress);
}

impl ERC20TokenImpl of TokenTrait<ERC20Amount> {
    fn is_allowed(self: @ERC20Amount, owner: ContractAddress, operator: ContractAddress) -> bool {
        check_erc20_allowed(self.get_dispatcher(), owner, operator, *self.amount)
    }
    fn is_owned(self: @ERC20Amount, owner: ContractAddress) -> bool {
        self.get_dispatcher().balance_of(owner) >= *self.amount
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
    fn is_owned(self: @ERC721Token, owner: ContractAddress) -> bool {
        self.get_dispatcher().owner_of(*self.token_id) == owner
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
    fn is_owned(self: @ERC721Tokens, owner: ContractAddress) -> bool {
        let dispatcher = self.get_dispatcher();
        let mut token_ids = self.token_ids.span();
        loop {
            match token_ids.pop_front() {
                Option::Some(token_id) => {
                    if dispatcher.owner_of(*token_id) != owner {
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
    fn is_owned(self: @Token, owner: ContractAddress) -> bool {
        match self {
            Token::ERC20(token) => token.is_owned(owner),
            Token::ERC721(token) => token.is_owned(owner),
            Token::ERC721s(tokens) => tokens.is_owned(owner),
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

impl ArrayTokenImpl<T, impl TTokenImpl: TokenTrait<T>, +Drop<T>> of TokenTrait<Array<T>> {
    fn is_allowed(self: @Array<T>, owner: ContractAddress, operator: ContractAddress) -> bool {
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
    fn is_owned(self: @Array<T>, owner: ContractAddress) -> bool {
        let mut tokens = self.span();
        loop {
            match tokens.pop_front() {
                Option::Some(token) => { if !token.is_owned(owner) {
                    break false;
                } },
                Option::None => { break true; },
            }
        }
    }
    fn transfer(self: Array<T>, to: ContractAddress) {
        for token in self {
            token.transfer(to);
        }
    }

    fn transfer_from(self: Array<T>, from: ContractAddress, to: ContractAddress) {
        for token in self {
            token.transfer_from(from, to);
        }
    }
}

impl TokenArrayTokenImpl = ArrayTokenImpl<Token, EnumTokenImpl>;
impl ERC20AmountArrayTokenImpl = ArrayTokenImpl<ERC20Amount, ERC20TokenImpl>;
// impl TokenArrayTokenImpl of TokenTrait<Array<Token>> {
//     fn is_allowed(self: @Array<Token>, owner: ContractAddress, operator: ContractAddress) -> bool
//     {
//         let mut tokens = self.span();
//         loop {
//             match tokens.pop_front() {
//                 Option::Some(token) => { if !token.is_allowed(owner, operator) {
//                     break false;
//                 } },
//                 Option::None => { break true; },
//             }
//         }
//     }
//     fn is_owned(self: @Array<Token>, owner: ContractAddress) -> bool {
//         let mut tokens = self.span();
//         loop {
//             match tokens.pop_front() {
//                 Option::Some(token) => { if !token.is_owned(owner) {
//                     break false;
//                 } },
//                 Option::None => { break true; },
//             }
//         }
//     }
//     fn transfer(self: Array<Token>, to: ContractAddress) {
//         for token in self {
//             token.transfer(to);
//         }
//     }

//     fn transfer_from(self: Array<Token>, from: ContractAddress, to: ContractAddress) {
//         for token in self {
//             token.transfer_from(from, to);
//         }
//     }
// }

// impl ERC20AmountArrayTokenImpl of TokenTrait<Array<ERC20Amount>> {
//     fn is_allowed(
//         self: @Array<ERC20Amount>, owner: ContractAddress, operator: ContractAddress,
//     ) -> bool {
//         let mut tokens = self.span();
//         loop {
//             match tokens.pop_front() {
//                 Option::Some(token) => { if !token.is_allowed(owner, operator) {
//                     break false;
//                 } },
//                 Option::None => { break true; },
//             }
//         }
//     }
//     fn transfer(self: Array<ERC20Amount>, to: ContractAddress) {
//         for token in self {
//             token.transfer(to);
//         }
//     }

//     fn transfer_from(self: Array<ERC20Amount>, from: ContractAddress, to: ContractAddress) {
//         for token in self {
//             token.transfer_from(from, to);
//         }
//     }
// }


