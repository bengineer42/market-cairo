use starknet::ContractAddress;
use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

fn erc20_transfer(contract_address: ContractAddress, recipient: ContractAddress, amount: u256) {
    ERC20ABIDispatcher { contract_address }.transfer(recipient, amount);
}

fn erc20_transfer_from(
    contract_address: ContractAddress,
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: u256,
) {
    ERC20ABIDispatcher { contract_address }.transfer_from(sender, recipient, amount);
}
