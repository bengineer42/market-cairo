use starknet::{ContractAddress, ClassHash};
use market::{starknet::deploy_with_single_return, token::Token};
use super::interfaces;

pub fn deploy_direct_single(
    class_hash: ClassHash,
    salt: felt252,
    seller: ContractAddress,
    offer: Span<Token>,
    expiry: u64,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    erc20_address: ContractAddress,
    price: u256,
) -> (ContractAddress, felt252) {
    let mut calldata: Array<felt252> = array![seller.into()];
    Serde::serialize(@offer, ref calldata);
    calldata
        .append_span(
            [
                expiry.into(), beneficiary.into(), tax_ppm.into(), erc20_address.into(),
                price.low.into(), price.high.into(),
            ]
                .span(),
        );
    deploy_with_single_return(class_hash, salt, calldata.span())
}

#[starknet::component]
mod direct_single_component {
    use starknet::{ContractAddress, get_caller_address};
    use market::token::Token;

    use market::direct::core::{
        OfferTrait, direct_core_component::{DirectCoreImpl, HasComponent as HasCoreComponent},
    };
    use market::direct::interfaces::{IDirectSingle, IDirectManagerDispatcherTrait};

    #[storage]
    struct Storage {
        erc20_address: ContractAddress,
        price: u256,
    }

    #[generate_trait]
    impl DirectSingleInternalImpl<TContractState> of DirectSingleInternalTrait<TContractState> {
        fn set_price_and_token_address(
            ref self: ComponentState<TContractState>, erc20_address: ContractAddress, price: u256,
        ) {
            self.erc20_address.write(erc20_address);
            self.price.write(price);
        }
    }

    #[embeddable_as(DirectSingle)]
    impl IDirectSingleImpl<
        TContractState,
        impl ICore: HasCoreComponent<TContractState>,
        impl Offer: OfferTrait<TContractState>,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IDirectSingle<ComponentState<TContractState>> {
        fn purchase(ref self: ComponentState<TContractState>, offer_hash: felt252, price: u256) {
            assert(price == self.price.read(), 'Price does not match');

            let mut core = get_dep_component_mut!(ref self, ICore);
            core
                .assert_hash_and_take_payment(
                    get_caller_address(), offer_hash, (self.erc20_address.read(), price),
                );
        }

        fn set_price(ref self: ComponentState<TContractState>, price: u256) {
            let mut core = get_dep_component_mut!(ref self, ICore);
            core.assert_caller_is_seller();
            self.price.write(price);
            core.manager_dispatcher().set_single_new_price(price);
        }

        fn price(self: @ComponentState<TContractState>) -> u256 {
            self.price.read()
        }

        fn erc20_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.erc20_address.read()
        }
    }
}
