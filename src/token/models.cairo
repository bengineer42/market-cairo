use starknet::ContractAddress;
use market::hash::HashValueTrait;

#[derive(Drop, Serde, Introspect)]
pub struct ERC20Amount {
    contract_address: ContractAddress,
    amount: u256,
}

#[derive(Drop, Serde, Introspect)]
pub struct ERC721Token {
    contract_address: ContractAddress,
    token_id: u256,
}

#[derive(Drop, Serde, Introspect)]
pub struct ERC721Tokens {
    contract_address: ContractAddress,
    token_ids: Array<u256>,
}

#[derive(Drop, Serde, Introspect)]
pub enum Token {
    ERC20: ERC20Amount,
    ERC721: ERC721Token,
    ERC721s: ERC721Tokens,
}

#[generate_trait]
pub impl GetEnumValueImpl of GetEnumValueTrait {
    fn get_enum_value(self: @Token) -> u32 {
        match self {
            Token::ERC20(_) => 0,
            Token::ERC721(_) => 1,
            Token::ERC721s(_) => 2,
        }
    }
}

pub impl ERC721TokenHashImpl of HashValueTrait<ERC721Token> {
    fn hash_serialize(self: @ERC721Token) -> Span<felt252> {
        [(*self.contract_address).into(), (*self.token_id.low).into(), (*self.token_id.high).into()]
            .span()
    }
}

pub impl ERC721TokensHashImpl of HashValueTrait<ERC721Tokens> {
    fn hash_serialize(self: @ERC721Tokens) -> Span<felt252> {
        let mut output = ArrayTrait::<felt252>::new();
        Serde::serialize(self, ref output);
        output.span()
    }
}

pub impl ERC20AmountHashImpl of HashValueTrait<ERC20Amount> {
    fn hash_serialize(self: @ERC20Amount) -> Span<felt252> {
        [(*self.contract_address).into(), (*self.amount.low).into(), (*self.amount.high).into()]
            .span()
    }
}

pub impl TokenHashImpl of HashValueTrait<Token> {
    fn hash_serialize(self: @Token) -> Span<felt252> {
        let mut array: Array<felt252> = array![self.get_enum_value().into()];
        array
            .append_span(
                match self {
                    Token::ERC20(token) => token.hash_serialize(),
                    Token::ERC721(token) => token.hash_serialize(),
                    Token::ERC721s(token) => token.hash_serialize(),
                },
            );
        array.span()
    }
}

pub impl ArrayHashImpl<T, impl HashValue: HashValueTrait<T>> of HashValueTrait<Array<T>> {
    fn hash_serialize(self: @Array<T>) -> Span<felt252> {
        let mut output = ArrayTrait::<felt252>::new();
        for token in self.span() {
            output.append_span(token.hash_serialize());
        };
        output.span()
    }
}

pub impl TokenArrayHashImpl = ArrayHashImpl<Token, TokenHashImpl>;
pub impl ERC20AmountArrayHashImpl = ArrayHashImpl<ERC20Amount, ERC20AmountHashImpl>;

