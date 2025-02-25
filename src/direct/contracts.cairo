#[starknet::contract]
mod direct_single_guaranteed {
    use starknet::ContractAddress;
    use market::{
        direct::{core::{direct_core_component, direct_core_component::DirectCoreImpl}},
        token::Token,
    };
    use market::direct::offer::GuaranteedOfferTrait;
    use market::direct::single::{
        direct_single_component, direct_single_component::DirectSingleInternalTrait,
    };

    component!(path: direct_core_component, storage: core, event: CoreEvent);
    component!(path: direct_single_component, storage: single, event: SingleEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CoreEvent: direct_core_component::Event,
        SingleEvent: direct_single_component::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        core: direct_core_component::Storage,
        #[substorage(v0)]
        single: direct_single_component::Storage,
    }

    impl OfferImpl = GuaranteedOfferTrait<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        erc20_address: ContractAddress,
        price: u256,
    ) -> felt252 {
        self.single.set_price_and_token_address(erc20_address, price);
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_core_component::DirectImpl<ContractState, OfferImpl>;

    #[abi(embed_v0)]
    impl IDirectSingle = direct_single_component::DirectSingle<ContractState>;
}

#[starknet::contract]
mod direct_single_unguaranteed {
    use starknet::ContractAddress;
    use market::{
        direct::{core::{direct_core_component, direct_core_component::DirectCoreImpl}},
        token::Token,
    };
    use market::direct::offer::UnguaranteedOfferTrait;
    use market::direct::single::{
        direct_single_component, direct_single_component::DirectSingleInternalTrait,
    };

    component!(path: direct_core_component, storage: core, event: CoreEvent);
    component!(path: direct_single_component, storage: single, event: SingleEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CoreEvent: direct_core_component::Event,
        SingleEvent: direct_single_component::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        core: direct_core_component::Storage,
        #[substorage(v0)]
        single: direct_single_component::Storage,
    }

    impl OfferImpl = UnguaranteedOfferTrait<ContractState>;


    #[constructor]
    fn constructor(
        ref self: ContractState,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        erc20_address: ContractAddress,
        price: u256,
    ) -> felt252 {
        self.single.set_price_and_token_address(erc20_address, price);
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_core_component::DirectImpl<ContractState, OfferImpl>;

    #[abi(embed_v0)]
    impl IDirectSingle = direct_single_component::DirectSingle<ContractState>;
}


#[starknet::contract]
mod direct_one_of_guaranteed {
    use starknet::ContractAddress;
    use market::{
        direct::{core::{direct_core_component, direct_core_component::DirectCoreImpl}},
        token::Token,
    };
    use market::direct::offer::GuaranteedOfferTrait;
    use market::direct::one_of::{
        direct_one_of_component, direct_one_of_component::DirectOneOfInternalTrait,
    };


    component!(path: direct_core_component, storage: core, event: CoreEvent);
    component!(path: direct_one_of_component, storage: one_of, event: OneOfEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CoreEvent: direct_core_component::Event,
        OneOfEvent: direct_one_of_component::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        core: direct_core_component::Storage,
        #[substorage(v0)]
        one_of: direct_one_of_component::Storage,
    }

    impl OfferImpl = GuaranteedOfferTrait<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        prices: Array<(ContractAddress, u256)>,
    ) -> felt252 {
        self.one_of.set_prices(prices);
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_core_component::DirectImpl<ContractState, OfferImpl>;

    #[abi(embed_v0)]
    impl IDirectOneOf = direct_one_of_component::DirectOneOf<ContractState>;
}

#[starknet::contract]
mod direct_one_of_unguaranteed {
    use starknet::ContractAddress;
    use market::{
        direct::{core::{direct_core_component, direct_core_component::DirectCoreImpl}},
        token::Token,
    };
    use market::direct::offer::UnguaranteedOfferTrait;
    use market::direct::one_of::{
        direct_one_of_component, direct_one_of_component::DirectOneOfInternalTrait,
    };


    component!(path: direct_core_component, storage: core, event: CoreEvent);
    component!(path: direct_one_of_component, storage: one_of, event: OneOfEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CoreEvent: direct_core_component::Event,
        OneOfEvent: direct_one_of_component::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        core: direct_core_component::Storage,
        #[substorage(v0)]
        one_of: direct_one_of_component::Storage,
    }

    impl OfferImpl = UnguaranteedOfferTrait<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        prices: Array<(ContractAddress, u256)>,
    ) -> felt252 {
        self.one_of.set_prices(prices);
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }


    #[abi(embed_v0)]
    impl IDirect = direct_core_component::DirectImpl<ContractState, OfferImpl>;

    #[abi(embed_v0)]
    impl IDirectOneOf = direct_one_of_component::DirectOneOf<ContractState>;
}

#[starknet::contract]
mod direct_multiple_guaranteed {
    use starknet::ContractAddress;
    use market::{
        direct::{core::{direct_core_component, direct_core_component::DirectCoreImpl}},
        token::{Token, ERC20Amount},
    };
    use market::direct::offer::GuaranteedOfferTrait;
    use market::direct::multiple::{
        direct_multiple_component, direct_multiple_component::DirectMultipleInternalTrait,
    };

    component!(path: direct_core_component, storage: core, event: CoreEvent);
    component!(path: direct_multiple_component, storage: multiple, event: MultipleEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CoreEvent: direct_core_component::Event,
        MultipleEvent: direct_multiple_component::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        core: direct_core_component::Storage,
        #[substorage(v0)]
        multiple: direct_multiple_component::Storage,
    }

    impl OfferImpl = GuaranteedOfferTrait<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        ask: Array<ERC20Amount>,
    ) -> felt252 {
        self.multiple.write_ask(ask);
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_core_component::DirectImpl<ContractState, OfferImpl>;

    #[abi(embed_v0)]
    impl IDirectMultiple = direct_multiple_component::DirectMultiple<ContractState>;
}

#[starknet::contract]
mod direct_multiple_unguaranteed {
    use starknet::ContractAddress;
    use market::{
        direct::{core::{direct_core_component, direct_core_component::DirectCoreImpl}},
        token::{Token, ERC20Amount},
    };
    use market::direct::offer::UnguaranteedOfferTrait;
    use market::direct::multiple::{
        direct_multiple_component, direct_multiple_component::DirectMultipleInternalTrait,
    };

    component!(path: direct_core_component, storage: core, event: CoreEvent);
    component!(path: direct_multiple_component, storage: multiple, event: MultipleEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CoreEvent: direct_core_component::Event,
        MultipleEvent: direct_multiple_component::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        core: direct_core_component::Storage,
        #[substorage(v0)]
        multiple: direct_multiple_component::Storage,
    }

    impl OfferImpl = UnguaranteedOfferTrait<ContractState>;


    #[constructor]
    fn constructor(
        ref self: ContractState,
        seller: ContractAddress,
        offer: Array<Token>,
        expiry: u64,
        beneficiary: ContractAddress,
        tax_ppm: u32,
        ask: Array<ERC20Amount>,
    ) -> felt252 {
        self.multiple.write_ask(ask);
        self.core.initializer(seller, offer, expiry, beneficiary, tax_ppm)
    }

    #[abi(embed_v0)]
    impl IDirect = direct_core_component::DirectImpl<ContractState, OfferImpl>;

    #[abi(embed_v0)]
    impl IDirectMultiple = direct_multiple_component::DirectMultiple<ContractState>;
}
