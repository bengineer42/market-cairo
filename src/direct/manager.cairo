#[starknet::contract]
mod direct_manager {
    use starknet::{ContractAddress, ClassHash, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    use dojo::world::WorldStorage;
    use dojo_beacon::resource_component;
    use dojo_beacon::model::namespace;

    use market::token::{Token, ERC20Amount, TokenTrait};
    use market::direct::{
        deploy_direct_single, deploy_direct_multiple, deploy_direct_one_of, DirectType,
        DirectTypeTrait, errors, DirectEvents,
    };
    use market::starknet::get_origin_caller_address;

    use super::super::interfaces::IDirectManager;

    component!(path: resource_component, storage: resource, event: ResourceEvents);

    #[abi(embed_v0)]
    impl Resource = resource_component::BeaconResource<ContractState>;

    #[derive(Drop, starknet::Event)]
    struct ReturnContractAddress {
        #[key]
        contract_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ResourceEvents: resource_component::Event,
        Return: ReturnContractAddress,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        resource: resource_component::Storage,
        single_class_hash_unguaranteed: ClassHash,
        multiple_class_hash_unguaranteed: ClassHash,
        one_of_class_hash_unguaranteed: ClassHash,
        single_class_hash_guaranteed: ClassHash,
        multiple_class_hash_guaranteed: ClassHash,
        one_of_class_hash_guaranteed: ClassHash,
        owners: Map<ContractAddress, bool>,
        tax_ppm: u32,
        beneficiary: ContractAddress,
        contracts: Map<ContractAddress, DirectType>,
        salt: felt252,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        single_class_hash_unguaranteed: ClassHash,
        multiple_class_hash_unguaranteed: ClassHash,
        one_of_class_hash_unguaranteed: ClassHash,
        single_class_hash_guaranteed: ClassHash,
        multiple_class_hash_guaranteed: ClassHash,
        one_of_class_hash_guaranteed: ClassHash,
        direct_single_model_class_hash: ClassHash,
        direct_multiple_model_class_hash: ClassHash,
        direct_one_of_model_class_hash: ClassHash,
        direct_one_of_price_model_class_hash: ClassHash,
        tax_ppm: u32,
        beneficiary: ContractAddress,
    ) {
        self.single_class_hash_unguaranteed.write(single_class_hash_unguaranteed);
        self.multiple_class_hash_unguaranteed.write(multiple_class_hash_unguaranteed);
        self.one_of_class_hash_unguaranteed.write(one_of_class_hash_unguaranteed);
        self.single_class_hash_guaranteed.write(single_class_hash_guaranteed);
        self.multiple_class_hash_guaranteed.write(multiple_class_hash_guaranteed);
        self.one_of_class_hash_guaranteed.write(one_of_class_hash_guaranteed);
        self.tax_ppm.write(tax_ppm);
        self.beneficiary.write(beneficiary);
        self.owners.write(get_origin_caller_address(), true);
        self
            .emit_setup(
                direct_single_model_class_hash,
                direct_multiple_model_class_hash,
                direct_one_of_model_class_hash,
                direct_one_of_price_model_class_hash,
            );
    }
    #[abi(embed_v0)]
    impl IDirectManagerImpl of IDirectManager<ContractState> {
        fn new_single(
            ref self: ContractState,
            offer: Array<Token>,
            erc20_address: ContractAddress,
            price: u256,
            expiry: u64,
            tax_ppm: u32,
            guaranteed: bool,
        ) {
            let seller = get_caller_address();
            let offer_span = offer.span();
            let (contract, offer_hash) = self
                .deploy_direct_single(seller, offer_span, expiry, erc20_address, price, guaranteed);
            self
                .emit_new_single(
                    contract,
                    seller,
                    offer_span,
                    offer_hash,
                    guaranteed,
                    expiry,
                    erc20_address,
                    price,
                    self.beneficiary.read(),
                    self.tax_ppm.read(),
                );
            self.setup_contract(DirectType::Single, contract, seller, offer, guaranteed);
        }

        fn new_multiple(
            ref self: ContractState,
            offer: Array<Token>,
            ask: Array<ERC20Amount>,
            expiry: u64,
            tax_ppm: u32,
            guaranteed: bool,
        ) {
            let seller = get_caller_address();
            let offer_span = offer.span();
            let ask_span = ask.span();

            let (contract, offer_hash, ask_hash) = self
                .deploy_direct_multiple(seller, offer_span, expiry, ask_span, guaranteed);
            self
                .emit_new_multiple(
                    contract,
                    seller,
                    offer_span,
                    offer_hash,
                    guaranteed,
                    expiry,
                    ask_span,
                    ask_hash,
                    self.beneficiary.read(),
                    self.tax_ppm.read(),
                );
            self.setup_contract(DirectType::Multiple, contract, seller, offer, guaranteed);
        }

        fn new_one_of(
            ref self: ContractState,
            offer: Array<Token>,
            prices: Array<(ContractAddress, u256)>,
            expiry: u64,
            tax_ppm: u32,
            guaranteed: bool,
        ) {
            let seller = get_caller_address();
            let offer_span = offer.span();

            let (contract, offer_hash) = self
                .deploy_direct_one_of(seller, offer_span, expiry, prices.span(), guaranteed);
            self
                .emit_new_one_of(
                    contract,
                    seller,
                    offer_span,
                    offer_hash,
                    guaranteed,
                    expiry,
                    prices.span(),
                    self.beneficiary.read(),
                    self.tax_ppm.read(),
                );
            self.setup_contract(DirectType::OneOf, contract, seller, offer, guaranteed);
        }

        fn set_single_class_hash(ref self: ContractState, guaranteed: bool, class_hash: ClassHash) {
            self.assert_caller_is_owner();
            if guaranteed {
                self.single_class_hash_guaranteed.write(class_hash);
            } else {
                self.single_class_hash_unguaranteed.write(class_hash);
            }
        }

        fn set_multiple_class_hash(
            ref self: ContractState, guaranteed: bool, class_hash: ClassHash,
        ) {
            self.assert_caller_is_owner();
            if guaranteed {
                self.multiple_class_hash_guaranteed.write(class_hash);
            } else {
                self.multiple_class_hash_unguaranteed.write(class_hash);
            }
        }

        fn set_one_of_class_hash(ref self: ContractState, guaranteed: bool, class_hash: ClassHash) {
            self.assert_caller_is_owner();
            if guaranteed {
                self.one_of_class_hash_guaranteed.write(class_hash);
            } else {
                self.one_of_class_hash_unguaranteed.write(class_hash);
            }
        }

        fn get_single_class_hash(self: @ContractState, guaranteed: bool) -> ClassHash {
            if guaranteed {
                self.single_class_hash_guaranteed.read()
            } else {
                self.single_class_hash_unguaranteed.read()
            }
        }

        fn get_multiple_class_hash(self: @ContractState, guaranteed: bool) -> ClassHash {
            if guaranteed {
                self.multiple_class_hash_guaranteed.read()
            } else {
                self.multiple_class_hash_unguaranteed.read()
            }
        }

        fn get_one_of_class_hash(self: @ContractState, guaranteed: bool) -> ClassHash {
            if guaranteed {
                self.one_of_class_hash_guaranteed.read()
            } else {
                self.one_of_class_hash_unguaranteed.read()
            }
        }

        fn set_bought(ref self: ContractState, buyer: ContractAddress) {
            let (caller, direct_type) = self.assert_caller_is_deployed_contract();
            self.contracts.write(caller, DirectType::NotDirect);
            // DirectEvents::emit_bought(ref self, direct_type, caller, buyer);
            self.emit_bought(direct_type, caller, buyer);
        }
        fn set_paused(ref self: ContractState) {
            let (caller, direct_type) = self.assert_caller_is_deployed_contract();
            self.emit_paused(direct_type, caller, true);
        }
        fn set_resumed(ref self: ContractState) {
            let (caller, direct_type) = self.assert_caller_is_deployed_contract();
            self.emit_paused(direct_type, caller, false);
        }
        fn set_closed(ref self: ContractState) {
            let (caller, direct_type) = self.assert_caller_is_deployed_contract();
            self.contracts.write(caller, DirectType::NotDirect);
            self.emit_closed(direct_type, caller);
        }
        fn set_new_expiry(ref self: ContractState, expiry: u64) {
            let (caller, direct_type) = self.assert_caller_is_deployed_contract();
            self.emit_expiry(direct_type, caller, expiry);
        }
        fn set_new_offer(ref self: ContractState, offer: Span<Token>, offer_hash: felt252) {
            let (caller, direct_type) = self.assert_caller_is_deployed_contract();
            self.emit_offer(direct_type, caller, offer, offer_hash);
        }
        fn set_single_new_price(ref self: ContractState, price: u256) {
            let caller = self.assert_caller_is_direct_type(DirectType::Single);
            self.emit_single_price(caller, price);
        }
        fn set_one_of_new_price(
            ref self: ContractState, erc20_address: ContractAddress, price: u256,
        ) {
            let caller = self.assert_caller_is_direct_type(DirectType::OneOf);
            self.emit_one_of_price(caller, erc20_address, price);
        }
        fn set_one_of_remove_token(ref self: ContractState, erc20_address: ContractAddress) {
            let caller = self.assert_caller_is_direct_type(DirectType::OneOf);
            self.emit_one_of_price(caller, erc20_address, 0);
        }
        fn set_multiple_new_ask(
            ref self: ContractState, ask: Span<ERC20Amount>, ask_hash: felt252,
        ) {
            let caller = self.assert_caller_is_direct_type(DirectType::Multiple);
            self.emit_multiple_ask(caller, ask, ask_hash);
        }
        fn grant_owner(ref self: ContractState, contract_address: ContractAddress) {
            self.assert_caller_is_owner();
            self.owners.write(contract_address, true);
        }
        fn revoke_owner(ref self: ContractState, contract_address: ContractAddress) {
            self.assert_caller_is_owner();
            self.owners.write(contract_address, false);
        }
        fn is_owner(self: @ContractState, contract_address: ContractAddress) -> bool {
            self.owners.read(contract_address)
        }
        fn set_beneficiary(ref self: ContractState, beneficiary: ContractAddress) {
            self.assert_caller_is_owner();
            self.beneficiary.write(beneficiary);
        }
        fn set_tax(ref self: ContractState, ppm: u32) {
            self.assert_caller_is_owner();
            self.tax_ppm.write(ppm);
        }
        fn tax_ppm(self: @ContractState) -> u32 {
            self.tax_ppm.read()
        }
        fn beneficiary(self: @ContractState) -> ContractAddress {
            self.beneficiary.read()
        }
    }


    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn deploy_direct_single(
            ref self: ContractState,
            seller: ContractAddress,
            offer: Span<Token>,
            expiry: u64,
            erc20_address: ContractAddress,
            price: u256,
            guaranteed: bool,
        ) -> (ContractAddress, felt252) {
            deploy_direct_single(
                self.get_single_class_hash(guaranteed),
                self.next_salt(),
                seller,
                offer,
                expiry,
                self.beneficiary(),
                self.tax_ppm(),
                erc20_address,
                price,
            )
        }
        fn deploy_direct_multiple(
            ref self: ContractState,
            seller: ContractAddress,
            offer: Span<Token>,
            expiry: u64,
            ask: Span<ERC20Amount>,
            guaranteed: bool,
        ) -> (ContractAddress, felt252, felt252) {
            deploy_direct_multiple(
                self.get_single_class_hash(guaranteed),
                self.next_salt(),
                seller,
                offer,
                expiry,
                self.beneficiary(),
                self.tax_ppm(),
                ask,
            )
        }


        fn deploy_direct_one_of(
            ref self: ContractState,
            seller: ContractAddress,
            offer: Span<Token>,
            expiry: u64,
            prices: Span<(ContractAddress, u256)>,
            guaranteed: bool,
        ) -> (ContractAddress, felt252) {
            deploy_direct_one_of(
                self.get_one_of_class_hash(guaranteed),
                self.next_salt(),
                seller,
                offer,
                expiry,
                self.beneficiary(),
                self.tax_ppm(),
                prices,
            )
        }

        fn next_salt(ref self: ContractState) -> felt252 {
            let salt = self.salt.read();
            self.salt.write(salt + 1);
            salt
        }

        fn assert_caller_is_owner(ref self: ContractState) {
            assert(self.owners.read(get_caller_address()), 'Caller is not an owner');
        }

        fn assert_caller_is_deployed_contract(
            ref self: ContractState,
        ) -> (ContractAddress, DirectType) {
            let caller = get_caller_address();
            let direct_type = self.contracts.read(caller);
            if direct_type == DirectType::NotDirect {
                errors::is_not_direct(caller, direct_type);
            }
            (caller, direct_type)
        }

        fn assert_caller_is_direct_type(
            ref self: ContractState, expected_type: DirectType,
        ) -> ContractAddress {
            let caller = get_caller_address();
            let direct_type = self.contracts.read(caller);
            if direct_type == expected_type {
                errors::is_not_direct_type(caller, direct_type, expected_type);
            }
            caller
        }

        fn setup_contract(
            ref self: ContractState,
            direct_type: DirectType,
            contract: ContractAddress,
            seller: ContractAddress,
            offer: Array<Token>,
            guaranteed: bool,
        ) {
            self.contracts.write(contract, direct_type);
            if guaranteed {
                offer.transfer_from(seller, contract);
            } else {
                assert(offer.is_owned(seller), 'You must own tokens for sale');
            }
            self.emit(ReturnContractAddress { contract_address: contract });
        }
    }
}
