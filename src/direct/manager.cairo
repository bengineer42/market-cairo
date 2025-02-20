#[dojo::contract]
mod direct_manager {
    use starknet::{ContractAddress, ClassHash, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    use dojo::world::WorldStorage;

    use market::token::{Token, ERC20Amount, TokenTrait};
    use market::direct::{
        deploy_direct_single, deploy_direct_multiple, deploy_direct_one_of, DirectType,
        DirectTypeTrait, errors, DirectEvents,
    };
    use market::starknet::get_origin_caller_address;
    use super::super::interfaces::IDirectManager;
    const DIRECT_NAMESPACE: felt252 = selector!("direct");

    #[storage]
    struct Storage {
        single_class_hash: ClassHash,
        multiple_class_hash: ClassHash,
        one_of_class_hash: ClassHash,
        owners: Map<ContractAddress, bool>,
        tax_ppm: u32,
        beneficiary: ContractAddress,
        contracts: Map<ContractAddress, DirectType>,
        salt: felt252,
    }

    fn storage() -> WorldStorage {
        market::dojo::get_storage_from_hash(DIRECT_NAMESPACE)
    }

    fn dojo_init(
        ref self: ContractState,
        single_class_hash: ClassHash,
        multiple_class_hash: ClassHash,
        one_of_class_hash: ClassHash,
        tax_ppm: u32,
        beneficiary: ContractAddress,
    ) {
        self.single_class_hash.write(single_class_hash);
        self.multiple_class_hash.write(multiple_class_hash);
        self.one_of_class_hash.write(one_of_class_hash);
        self.tax_ppm.write(tax_ppm);
        self.beneficiary.write(beneficiary);
        self.owners.write(get_origin_caller_address(), true);
    }

    impl IDirectManagerImpl of IDirectManager<ContractState> {
        fn new_single(
            ref self: ContractState,
            offer: Array<Token>,
            erc20_address: ContractAddress,
            price: u256,
            expiry: u64,
            tax_ppm: u32,
        ) {
            let seller = get_caller_address();
            let offer_span = offer.span();
            let (contract, offer_hash) = self
                .deploy_direct_single(seller, offer_span, expiry, erc20_address, price);
            let mut storage = storage();
            storage
                .emit_direct_new(
                    contract,
                    seller,
                    offer_span,
                    offer_hash,
                    expiry,
                    self.beneficiary.read(),
                    self.tax_ppm.read(),
                );
            storage.emit_direct_single_token_address(contract, erc20_address);
            storage.emit_direct_single_price(contract, price);
            self.setup_contract(contract, seller, offer, DirectType::Single);
        }

        fn new_multiple(
            ref self: ContractState,
            offer: Array<Token>,
            ask: Array<ERC20Amount>,
            expiry: u64,
            tax_ppm: u32,
        ) {
            let seller = get_caller_address();
            let offer_span = offer.span();
            let ask_span = ask.span();

            let (contract, offer_hash, ask_hash) = self
                .deploy_direct_multiple(seller, offer_span, expiry, ask_span);
            let mut storage = storage();
            storage
                .emit_direct_new(
                    contract,
                    seller,
                    offer_span,
                    offer_hash,
                    expiry,
                    self.beneficiary.read(),
                    self.tax_ppm.read(),
                );
            storage.emit_direct_multiple_ask(contract, ask_span, ask_hash);
            self.setup_contract(contract, seller, offer, DirectType::Multiple);
        }

        fn new_one_of(
            ref self: ContractState,
            offer: Array<Token>,
            prices: Array<(ContractAddress, u256)>,
            expiry: u64,
            tax_ppm: u32,
        ) {
            let seller = get_caller_address();
            let offer_span = offer.span();

            let (contract, offer_hash) = self
                .deploy_direct_one_of(seller, offer_span, expiry, prices.span());

            let mut storage = storage();
            storage
                .emit_direct_new(
                    contract,
                    seller,
                    offer_span,
                    offer_hash,
                    expiry,
                    self.beneficiary.read(),
                    self.tax_ppm.read(),
                );
            for (erc20_address, price) in prices {
                storage.emit_direct_one_of_price(contract, erc20_address, price);
            };
            self.setup_contract(contract, seller, offer, DirectType::OneOf);
            // TODO: emit event
        }

        fn set_single_class_hash(ref self: ContractState, class_hash: ClassHash) {
            self.assert_caller_is_owner();
            self.single_class_hash.write(class_hash);
        }

        fn set_multiple_class_hash(ref self: ContractState, class_hash: ClassHash) {
            self.assert_caller_is_owner();
            self.multiple_class_hash.write(class_hash);
        }

        fn set_one_of_class_hash(ref self: ContractState, class_hash: ClassHash) {
            self.assert_caller_is_owner();
            self.one_of_class_hash.write(class_hash);
        }

        fn get_single_class_hash(self: @ContractState) -> ClassHash {
            self.single_class_hash.read()
        }

        fn get_multiple_class_hash(self: @ContractState) -> ClassHash {
            self.multiple_class_hash.read()
        }

        fn get_one_of_class_hash(self: @ContractState) -> ClassHash {
            self.one_of_class_hash.read()
        }

        fn set_bought(ref self: ContractState, buyer: ContractAddress) {
            let caller = self.assert_caller_is_deployed_contract();
            self.contracts.write(caller, DirectType::NotDirect);
            storage().emit_direct_bought(caller, buyer);
        }
        fn set_paused(ref self: ContractState) {
            let caller = self.assert_caller_is_deployed_contract();
            storage().emit_direct_paused(caller, true);
        }
        fn set_resumed(ref self: ContractState) {
            let caller = self.assert_caller_is_deployed_contract();
            storage().emit_direct_paused(caller, false);
        }
        fn set_closed(ref self: ContractState) {
            let caller = self.assert_caller_is_deployed_contract();
            self.contracts.write(caller, DirectType::NotDirect);
            storage().emit_direct_closed(caller);
        }
        fn set_new_expiry(ref self: ContractState, expiry: u64) {
            let caller = self.assert_caller_is_deployed_contract();
            storage().emit_direct_expiry(caller, expiry);
        }
        fn set_new_offer(ref self: ContractState, offer: Span<Token>, offer_hash: felt252) {
            let caller = self.assert_caller_is_deployed_contract();
            storage().emit_direct_offer(caller, offer, offer_hash);
        }
        fn set_single_new_price(ref self: ContractState, price: u256) {
            let caller = self.assert_caller_is_direct_type(DirectType::Single);
            storage().emit_direct_single_price(caller, price);
        }
        fn set_one_of_new_price(
            ref self: ContractState, erc20_address: ContractAddress, price: u256,
        ) {
            let caller = self.assert_caller_is_direct_type(DirectType::OneOf);
            storage().emit_direct_one_of_price(caller, erc20_address, price);
        }
        fn set_one_of_remove_token(ref self: ContractState, erc20_address: ContractAddress) {
            let caller = self.assert_caller_is_direct_type(DirectType::OneOf);
            storage().emit_direct_one_of_price(caller, erc20_address, 0);
        }
        fn set_multiple_new_ask(
            ref self: ContractState, ask: Span<ERC20Amount>, ask_hash: felt252,
        ) {
            let caller = self.assert_caller_is_direct_type(DirectType::Multiple);
            storage().emit_direct_multiple_ask(caller, ask, ask_hash);
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
        fn deploy_direct_multiple(
            ref self: ContractState,
            seller: ContractAddress,
            offer: Span<Token>,
            expiry: u64,
            ask: Span<ERC20Amount>,
        ) -> (ContractAddress, felt252, felt252) {
            deploy_direct_multiple(
                self.multiple_class_hash.read(),
                self.next_salt(),
                seller,
                offer,
                expiry,
                self.beneficiary(),
                self.tax_ppm(),
                ask,
            )
        }

        fn deploy_direct_single(
            ref self: ContractState,
            seller: ContractAddress,
            offer: Span<Token>,
            expiry: u64,
            erc20_address: ContractAddress,
            price: u256,
        ) -> (ContractAddress, felt252) {
            deploy_direct_single(
                self.single_class_hash.read(),
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

        fn deploy_direct_one_of(
            ref self: ContractState,
            seller: ContractAddress,
            offer: Span<Token>,
            expiry: u64,
            prices: Span<(ContractAddress, u256)>,
        ) -> (ContractAddress, felt252) {
            deploy_direct_one_of(
                self.one_of_class_hash.read(),
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

        fn assert_caller_is_deployed_contract(ref self: ContractState) -> ContractAddress {
            let caller = get_caller_address();
            let direct_type = self.contracts.read(caller);
            if direct_type == DirectType::NotDirect {
                errors::is_not_direct(caller, direct_type);
            }
            caller
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
            contract: ContractAddress,
            seller: ContractAddress,
            offer: Array<Token>,
            direct_type: DirectType,
        ) {
            offer.transfer_from(seller, contract);
            self.contracts.write(contract, direct_type);
        }
    }
}
