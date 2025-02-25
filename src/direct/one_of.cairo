use starknet::{ContractAddress, ClassHash};
use market::{starknet::deploy_with_single_return, token::Token};
use super::interfaces;

pub fn deploy_direct_one_of(
    class_hash: ClassHash,
    salt: felt252,
    seller: ContractAddress,
    offer: Span<Token>,
    expiry: u64,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    prices: Span<(ContractAddress, u256)>,
) -> (ContractAddress, felt252) {
    let mut calldata: Array<felt252> = array![seller.into()];
    Serde::serialize(@offer, ref calldata);
    calldata.append_span([expiry.into(), beneficiary.into(), tax_ppm.into()].span());
    Serde::serialize(@prices, ref calldata);
    deploy_with_single_return(class_hash, salt, calldata.span())
}

#[starknet::component]
mod direct_one_of_component {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use market::token::Token;

    use market::direct::core::{
        OfferTrait, direct_core_component::{DirectCoreImpl, HasComponent as HasCoreComponent},
    };
    use market::direct::interfaces::{IDirectOneOf, IDirectManagerDispatcherTrait};

    #[storage]
    struct Storage {
        prices: Map<ContractAddress, u256>,
    }

    #[generate_trait]
    impl DirectOneOfInternalImpl<TContractState> of DirectOneOfInternalTrait<TContractState> {
        fn set_prices(
            ref self: ComponentState<TContractState>, prices: Array<(ContractAddress, u256)>,
        ) {
            for (erc20_address, price) in prices {
                self.prices.entry(erc20_address).write(price);
            }
        }
    }

    #[embeddable_as(DirectOneOf)]
    impl IDirectSingleImpl<
        TContractState,
        impl ICore: HasCoreComponent<TContractState>,
        impl Offer: OfferTrait<TContractState>,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IDirectOneOf<ComponentState<TContractState>> {
        fn purchase(
            ref self: ComponentState<TContractState>,
            offer_hash: felt252,
            erc20_address: ContractAddress,
            price: u256,
        ) {
            assert(price.is_non_zero(), 'ERC20 not useable');
            assert(price == self.prices.entry(erc20_address).read(), 'Price does not match');

            let mut core = get_dep_component_mut!(ref self, ICore);
            core
                .assert_hash_and_take_payment(
                    get_caller_address(), offer_hash, (erc20_address, price),
                );
        }

        fn set_price(
            ref self: ComponentState<TContractState>, erc20_address: ContractAddress, price: u256,
        ) {
            let mut core = get_dep_component_mut!(ref self, ICore);
            core.assert_caller_is_seller();
            self.prices.entry(erc20_address).write(price);
            core.manager_dispatcher().set_one_of_new_price(erc20_address, price);
        }

        fn remove_token(ref self: ComponentState<TContractState>, erc20_address: ContractAddress) {
            let mut core = get_dep_component_mut!(ref self, ICore);
            core.assert_caller_is_seller();
            self.set_price(erc20_address, 0);
            core.manager_dispatcher().set_one_of_remove_token(erc20_address);
        }

        fn price(self: @ComponentState<TContractState>, erc20_address: ContractAddress) -> u256 {
            self.prices.entry(erc20_address).read()
        }
    }
}
