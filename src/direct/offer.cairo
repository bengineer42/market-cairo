use starknet::{ContractAddress, get_contract_address};
use market::token::{Token, TokenTrait};
use market::direct::{
    core::{
        ComponentState, OfferTrait, read_offer,
        direct_core_component::{DirectCoreTrait, HasComponent},
    },
};


impl UnguaranteedOfferTrait<
    TContractState, +HasComponent<TContractState>,
> of OfferTrait<TContractState> {
    fn modify_offer_transfer(
        ref self: ComponentState<TContractState>,
        new_offer: @Array<Token>,
        add: Array<Token>,
        remove: Array<Token>,
    ) {
        assert(Self::verify_offer_ownership(@self), 'New Offer Incorrect');
    }
    fn return_goods(ref self: ComponentState<TContractState>, seller: ContractAddress) {
        self.closed.write(true);
    }
    fn transfer_goods_to(ref self: ComponentState<TContractState>, to: ContractAddress) {
        read_offer().transfer_from(self.seller.read(), to);
        self.closed.write(true);
    }
    fn verify_offer_ownership(self: @ComponentState<TContractState>) -> bool {
        let offer = read_offer();
        offer.is_owned(self.seller.read())
            && offer.is_allowed(self.seller.read(), get_contract_address())
    }
}

impl GuaranteedOfferTrait<
    TContractState, +HasComponent<TContractState>,
> of OfferTrait<TContractState> {
    fn modify_offer_transfer(
        ref self: ComponentState<TContractState>,
        new_offer: @Array<Token>,
        add: Array<Token>,
        remove: Array<Token>,
    ) {
        let seller = self.seller.read();
        add.transfer_from(seller, get_contract_address());
        remove.transfer(seller);
        assert(new_offer.is_owned(get_contract_address()), 'New Offer Incorrect');
    }
    fn return_goods(ref self: ComponentState<TContractState>, seller: ContractAddress) {
        read_offer().transfer(seller);
        self.closed.write(true);
    }
    fn transfer_goods_to(ref self: ComponentState<TContractState>, to: ContractAddress) {
        read_offer().transfer(to);
        self.closed.write(true);
    }
    fn verify_offer_ownership(self: @ComponentState<TContractState>) -> bool {
        read_offer().is_owned(get_contract_address())
    }
}
