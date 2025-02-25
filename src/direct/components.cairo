use core::panics::panic_with_byte_array;
use starknet::ContractAddress;

use super::models::{DIRECT_MULTIPLE_SELECTOR, DIRECT_ONE_OF_SELECTOR, DIRECT_SINGLE_SELECTOR};

fn get_namespace() -> ByteArray {
    "direct_market"
}

#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub enum DirectType {
    #[default]
    NotDirect,
    Single,
    Multiple,
    OneOf,
}

#[generate_trait]
impl DirectTypeImpl of DirectTypeTrait {
    fn name(self: @DirectType) -> ByteArray {
        match self {
            DirectType::NotDirect => "Not Direct",
            DirectType::Single => "Direct Single",
            DirectType::Multiple => "Direct Multiple",
            DirectType::OneOf => "Direct One Of",
        }
    }

    fn selector(self: @DirectType) -> felt252 {
        match self {
            DirectType::NotDirect => panic!("Not a model"),
            DirectType::Single => DIRECT_SINGLE_SELECTOR,
            DirectType::Multiple => DIRECT_MULTIPLE_SELECTOR,
            DirectType::OneOf => DIRECT_ONE_OF_SELECTOR,
        }
    }

    fn assert_is_type(self: @DirectType, expected: DirectType) {
        if *self != expected {
            panic_with_byte_array(
                @format!("Contract type is {} not {}.", self.name(), expected.name()),
            );
        }
    }

    fn assert_is_direct(self: @DirectType) {
        if *self == DirectType::NotDirect {
            panic_with_byte_array(@"Contract type not direct.");
        }
    }
}

mod errors {
    use core::panics::panic_with_byte_array;
    use starknet::ContractAddress;
    use super::{DirectType, DirectTypeTrait};
    fn is_not_direct_type(contract_address: ContractAddress, is: DirectType, expected: DirectType) {
        panic_with_byte_array(
            @format!("Contract {:?} is {} not {}.", contract_address, is.name(), expected.name()),
        );
    }

    fn is_not_direct(contract_address: ContractAddress, is: DirectType) {
        panic_with_byte_array(
            @format!("Contract {:?} is {} not direct.", contract_address, is.name()),
        );
    }
}
