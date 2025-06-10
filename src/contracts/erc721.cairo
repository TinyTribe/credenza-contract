#[starknet::contract]
pub mod CredenzaCredential {
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess};
    use core::byte_array::ByteArray;
    use core::integer::u256;
    use crate::interfaces::erc721::{CredentialMetadata, CredentialStatus, ICredenzaCredential, BatchMintRequest};
    use crate::contracts::mock_issuer_registry::{IIssuerRegistryDispatcher, IIssuerRegistryDispatcherTrait};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        credential_data: Map<u256, CredentialMetadata>,
        issuer_registry_address: ContractAddress,
        token_uris: Map<u256, ByteArray>,
        issuer_permissions: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        CredentialRevoked: CredentialRevoked,
        CredentialMinted: CredentialMinted,
        CredentialRenewed: CredentialRenewed,
        BatchMinted: BatchMinted,
        BatchRevoked: BatchRevoked,
        IssuerPermissionsSet: IssuerPermissionsSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CredentialRevoked {
        #[key]
        pub token_id: u256,
        pub issuer: ContractAddress,
        pub reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CredentialMinted {
        #[key]
        pub token_id: u256,
        pub recipient: ContractAddress,
        pub issuer: ContractAddress,
        pub schema_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CredentialRenewed {
        #[key]
        pub token_id: u256,
        pub old_expiration: u64,
        pub new_expiration: u64,
        pub renewed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchMinted {
        pub issuer: ContractAddress,
        pub count: u32,
        pub schema_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchRevoked {
        pub issuer: ContractAddress,
        pub count: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IssuerPermissionsSet {
        pub issuer: ContractAddress,
        pub can_mint: bool,
        pub can_revoke: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        issuer_registry_address: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        owner: ContractAddress
    ) {
        let base_uri = "";
        self.erc721.initializer(name, symbol, base_uri);
        self.ownable.initializer(owner);
        self.issuer_registry_address.write(issuer_registry_address);
    }
    
    #[abi(embed_v0)]
    impl CredenzaCredentialImpl of ICredenzaCredential<ContractState> {
        fn mint(
            ref self: ContractState,
            recipient: ContractAddress,
            token_id: u256,
            token_uri: ByteArray,
            expiration_date: u64,
            schema_id: felt252
        ) {
            self.mint_with_details(
                recipient, token_id, token_uri, expiration_date, schema_id, 'default', 1, false
            );
        }

        fn mint_with_details(
            ref self: ContractState,
            recipient: ContractAddress,
            token_id: u256,
            token_uri: ByteArray,
            expiration_date: u64,
            schema_id: felt252,
            credential_type: felt252,
            level: u8,
            renewable: bool
        ) {
            let caller = get_caller_address();
            assert(self.can_issuer_mint(caller), 'CREDENTIAL: NOT_VERIFIED_ISSUER');
            
            if expiration_date != 0 {
                let now = get_block_timestamp();
                assert(expiration_date > now, 'CREDENTIAL: INVALID_EXPIRATION');
            }

            self.erc721.mint(recipient, token_id);
            self.token_uris.write(token_id, token_uri);

            let metadata = CredentialMetadata {
                issuer: caller,
                issuance_date: get_block_timestamp(),
                expiration_date: expiration_date,
                status: CredentialStatus::Active,
                schema_id: schema_id,
                credential_type: credential_type,
                level: level,
                renewable: renewable,
            };
            
            self.credential_data.write(token_id, metadata);
            self.emit(CredentialMinted { token_id, recipient, issuer: caller, schema_id });
        }

        fn revoke(ref self: ContractState, token_id: u256) {
            self.revoke_with_reason(token_id, 'REVOKED');
        }

        fn revoke_with_reason(ref self: ContractState, token_id: u256, reason: felt252) {
            let caller = get_caller_address();
            let metadata = self.credential_data.read(token_id);
            assert(caller == metadata.issuer, 'CREDENTIAL: NOT_ISSUER');

            let updated_metadata = CredentialMetadata {
                status: CredentialStatus::Revoked,
                issuer: metadata.issuer,
                issuance_date: metadata.issuance_date,
                expiration_date: metadata.expiration_date,
                schema_id: metadata.schema_id,
                credential_type: metadata.credential_type,
                level: metadata.level,
                renewable: metadata.renewable,
            };
            self.credential_data.write(token_id, updated_metadata);
            self.emit(CredentialRevoked { token_id, issuer: caller, reason });
        }

        fn is_expired(self: @ContractState, token_id: u256) -> bool {
            let metadata = self.credential_data.read(token_id);
            if metadata.expiration_date == 0 {
                return false;
            }
            let now = get_block_timestamp();
            metadata.expiration_date < now
        }

        fn is_valid(self: @ContractState, token_id: u256) -> bool {
            let metadata = self.credential_data.read(token_id);
            metadata.status == CredentialStatus::Active && !self.is_expired(token_id)
        }

        fn renew_credential(ref self: ContractState, token_id: u256, new_expiration: u64) {
            let caller = get_caller_address();
            let metadata = self.credential_data.read(token_id);
            assert(caller == metadata.issuer, 'CREDENTIAL: NOT_ISSUER');
            assert(metadata.renewable, 'CREDENTIAL: NOT_RENEWABLE');

            let old_expiration = metadata.expiration_date;
            let updated_metadata = CredentialMetadata {
                expiration_date: new_expiration,
                status: CredentialStatus::Active,
                issuer: metadata.issuer,
                issuance_date: metadata.issuance_date,
                schema_id: metadata.schema_id,
                credential_type: metadata.credential_type,
                level: metadata.level,
                renewable: metadata.renewable,
            };
            self.credential_data.write(token_id, updated_metadata);

            self.emit(CredentialRenewed { 
                token_id, old_expiration, new_expiration, renewed_by: caller 
            });
        }

        fn get_credential_metadata(self: @ContractState, token_id: u256) -> CredentialMetadata {
            self.credential_data.read(token_id)
        }

        fn get_credential_status(self: @ContractState, token_id: u256) -> CredentialStatus {
            let metadata = self.credential_data.read(token_id);
            if metadata.status == CredentialStatus::Revoked {
                return CredentialStatus::Revoked;
            }
            if self.is_expired(token_id) {
                return CredentialStatus::Expired;
            }
            CredentialStatus::Active
        }

        fn get_credential_schema(self: @ContractState, token_id: u256) -> felt252 {
            let metadata = self.credential_data.read(token_id);
            metadata.schema_id
        }

        fn update_metadata(ref self: ContractState, token_id: u256, new_uri: ByteArray) {
            let caller = get_caller_address();
            let metadata = self.credential_data.read(token_id);
            assert(caller == metadata.issuer, 'CREDENTIAL: NOT_ISSUER');
            self.token_uris.write(token_id, new_uri);
        }

        fn batch_mint(ref self: ContractState, requests: Array<BatchMintRequest>) {
            let caller = get_caller_address();
            assert(self.can_issuer_mint(caller), 'CREDENTIAL: NOT_VERIFIED_ISSUER');

            let requests_span = requests.span();
            let count = requests_span.len();
            assert(count > 0, 'CREDENTIAL: EMPTY_BATCH');
            assert(count <= 50, 'CREDENTIAL: BATCH_TOO_LARGE');

            let mut i = 0;
            let first_schema_id = requests_span.at(0).schema_id;

            while i < count {
                let request = requests_span.at(i);
                self.mint_with_details(
                    *request.recipient, *request.token_id, request.token_uri.clone(),
                    *request.expiration_date, *request.schema_id, *request.credential_type,
                    *request.level, *request.renewable
                );
                i += 1;
            };

            self.emit(BatchMinted { 
                issuer: caller, count: count.try_into().unwrap(), schema_id: *first_schema_id 
            });
        }

        fn batch_revoke(ref self: ContractState, token_ids: Array<u256>) {
            let token_ids_span = token_ids.span();
            let count = token_ids_span.len();
            assert(count > 0, 'CREDENTIAL: EMPTY_BATCH');
            assert(count <= 50, 'CREDENTIAL: BATCH_TOO_LARGE');

            let mut i = 0;
            let caller = get_caller_address();
            while i < count {
                let token_id = *token_ids_span.at(i);
                self.revoke_with_reason(token_id, 'BATCH_REVOKED');
                i += 1;
            };

            self.emit(BatchRevoked { 
                issuer: caller, 
                count: count.try_into().unwrap() 
            });
        }

        fn get_user_credentials(
            self: @ContractState, user: ContractAddress, offset: u32, limit: u32
        ) -> Array<u256> {
            array![]
        }

        fn get_credentials_by_schema(
            self: @ContractState, schema_id: felt252, offset: u32, limit: u32
        ) -> Array<u256> {
            array![]
        }

        fn get_active_credential_count(self: @ContractState, user: ContractAddress) -> u32 {
            0
        }

        fn has_credential_type(
            self: @ContractState, user: ContractAddress, credential_type: felt252
        ) -> bool {
            false
        }

        fn set_issuer_permissions(
            ref self: ContractState, issuer: ContractAddress, can_mint: bool, can_revoke: bool
        ) {
            self.ownable.assert_only_owner();
            self.issuer_permissions.write(issuer, can_mint);
            self.emit(IssuerPermissionsSet { issuer, can_mint, can_revoke });
        }

        fn can_issuer_mint(self: @ContractState, issuer: ContractAddress) -> bool {
            let has_local_permission = self.issuer_permissions.read(issuer);
            if has_local_permission {
                return true;
            }

            let issuer_registry = IIssuerRegistryDispatcher { 
                contract_address: self.issuer_registry_address.read() 
            };
            issuer_registry.is_verified_issuer(issuer)
        }

        fn update_issuer_registry(ref self: ContractState, new_registry: ContractAddress) {
            self.ownable.assert_only_owner();
            self.issuer_registry_address.write(new_registry);
        }
    }
} 