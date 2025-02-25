use starknet::{ContractAddress, ClassHash};
use market::{starknet::deploy_with_double_return, token::{Token, ERC20Amount}};
use super::interfaces;

pub fn deploy_direct_multiple(
    class_hash: ClassHash,
    salt: felt252,
    seller: ContractAddress,
    offer: Span<Token>,
    expiry: u64,
    beneficiary: ContractAddress,
    tax_ppm: u32,
    ask: Span<ERC20Amount>,
) -> (ContractAddress, felt252, felt252) {
    let mut calldata: Array<felt252> = array![seller.into()];
    Serde::serialize(@offer, ref calldata);
    calldata.append_span([expiry.into(), beneficiary.into(), tax_ppm.into()].span());
    Serde::serialize(@ask, ref calldata);
    deploy_with_double_return(class_hash, salt, calldata.span())
}

#[starknet::component]
mod direct_multiple_component {
    use starknet::{ContractAddress, get_caller_address};
    use market::token::{Token, ERC20Amount, StoreGoodsTrait, models::ArrayHashImpl};
    use market::hash::HashValueTrait;
    use market::direct::core::{
        OfferTrait, direct_core_component::{DirectCoreImpl, HasComponent as HasCoreComponent},
    };
    use market::direct::interfaces::{IDirectMultiple, IDirectManagerDispatcherTrait};

    const ASK_ADDRESS: felt252 = selector!("ask");

    #[storage]
    struct Storage {
        ask_hash: felt252,
    }

    #[generate_trait]
    impl DirectMultipleInternalImpl<TContractState> of DirectMultipleInternalTrait<TContractState> {
        fn read_ask(self: @ComponentState<TContractState>) -> Array<ERC20Amount> {
            StoreGoodsTrait::read_goods(ASK_ADDRESS)
        }

        fn write_ask(ref self: ComponentState<TContractState>, ask: Array<ERC20Amount>) -> felt252 {
            let ask_hash = ask.hash_value();
            self.ask_hash.write(ask_hash);
            ask.write_goods(ASK_ADDRESS);
            ask_hash
        }
    }

    #[embeddable_as(DirectMultiple)]
    impl IDirectMultipleImpl<
        TContractState,
        impl ICore: HasCoreComponent<TContractState>,
        impl Offer: OfferTrait<TContractState>,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IDirectMultiple<ComponentState<TContractState>> {
        fn purchase(
            ref self: ComponentState<TContractState>, offer_hash: felt252, ask_hash: felt252,
        ) {
            assert(self.ask_hash.read() == ask_hash, 'Ask hash does not match');
            let mut core = get_dep_component_mut!(ref self, ICore);
            core.assert_hash_and_take_payment(get_caller_address(), offer_hash, self.read_ask());
        }

        fn set_ask(ref self: ComponentState<TContractState>, ask: Array<ERC20Amount>) {
            let mut core = get_dep_component_mut!(ref self, ICore);

            core.assert_caller_is_seller();
            let ask_span = ask.span();
            let ask_hash = self.write_ask(ask);
            core.manager_dispatcher().set_multiple_new_ask(ask_span, ask_hash);
        }

        fn ask_hash(self: @ComponentState<TContractState>) -> felt252 {
            self.ask_hash.read()
        }
        fn ask(self: @ComponentState<TContractState>) -> Array<ERC20Amount> {
            self.read_ask()
        }
        fn ask_and_hash(self: @ComponentState<TContractState>) -> (Array<ERC20Amount>, felt252) {
            (self.read_ask(), self.ask_hash.read())
        }
    }
}

