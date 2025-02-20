use core::num::traits::WideMul;
use core::integer::u512_safe_div_rem_by_u256;

use starknet::ContractAddress;

use openzeppelin_token::{erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait}};

use market::token::{ERC20Amount, DispatcherTrait};


fn calc_tax(amount: u256, tax_ppm: u32) -> u256 {
    let (val, _) = u512_safe_div_rem_by_u256(amount.wide_mul(tax_ppm.into()), 1_000_000);
    val.try_into().unwrap()
}

fn split_tax(amount: u256, tax_ppm: u32) -> (u256, u256) {
    let tax = calc_tax(amount, tax_ppm);
    (amount - tax, tax)
}

trait TransferAndTax<T> {
    fn transfer_and_tax(self: T, to: ContractAddress, tax_ppm: u32, beneficiary: ContractAddress);

    fn transfer_from_and_tax(
        self: T,
        from: ContractAddress,
        to: ContractAddress,
        tax_ppm: u32,
        beneficiary: ContractAddress,
    );
}

impl ContractAddressAndU256TransferAndTaxImpl of TransferAndTax<(ContractAddress, u256)> {
    fn transfer_and_tax(
        self: (ContractAddress, u256),
        to: ContractAddress,
        tax_ppm: u32,
        beneficiary: ContractAddress,
    ) {
        let (token_address, total) = self;
        let dispatcher = ERC20ABIDispatcher { contract_address: token_address };
        let (amount, tax) = split_tax(total, tax_ppm);

        dispatcher.transfer(to, amount);
        dispatcher.transfer(beneficiary, tax);
    }
    fn transfer_from_and_tax(
        self: (ContractAddress, u256),
        from: ContractAddress,
        to: ContractAddress,
        tax_ppm: u32,
        beneficiary: ContractAddress,
    ) {
        let (token_address, total) = self;
        let dispatcher = ERC20ABIDispatcher { contract_address: token_address };
        let (amount, tax) = split_tax(total, tax_ppm);

        dispatcher.transfer_from(from, to, amount);
        dispatcher.transfer_from(from, beneficiary, tax);
    }
}

impl ERC20AmountTransferAndTaxImpl of TransferAndTax<ERC20Amount> {
    fn transfer_and_tax(
        self: ERC20Amount, to: ContractAddress, tax_ppm: u32, beneficiary: ContractAddress,
    ) {
        let dispatcher = self.get_dispatcher();
        let (amount, tax) = split_tax(self.amount, tax_ppm);

        dispatcher.transfer(to, amount);
        dispatcher.transfer(beneficiary, tax);
    }
    fn transfer_from_and_tax(
        self: ERC20Amount,
        from: ContractAddress,
        to: ContractAddress,
        tax_ppm: u32,
        beneficiary: ContractAddress,
    ) {
        let dispatcher = self.get_dispatcher();
        let (amount, tax) = split_tax(self.amount, tax_ppm);

        dispatcher.transfer_from(from, to, amount);
        dispatcher.transfer_from(from, beneficiary, tax);
    }
}

impl ERC20AmountArrayTransferAndTaxImpl of TransferAndTax<Array<ERC20Amount>> {
    fn transfer_and_tax(
        self: Array<ERC20Amount>, to: ContractAddress, tax_ppm: u32, beneficiary: ContractAddress,
    ) {
        for amount in self {
            amount.transfer_and_tax(to, tax_ppm, beneficiary);
        }
    }
    fn transfer_from_and_tax(
        self: Array<ERC20Amount>,
        from: ContractAddress,
        to: ContractAddress,
        tax_ppm: u32,
        beneficiary: ContractAddress,
    ) {
        for amount in self {
            amount.transfer_from_and_tax(from, to, tax_ppm, beneficiary);
        }
    }
}

