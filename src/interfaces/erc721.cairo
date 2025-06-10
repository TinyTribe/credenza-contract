use starknet::ContractAddress;
use core::integer::u256;
use core::byte_array::ByteArray;

#[derive(Serde, Drop, Copy, starknet::Store, PartialEq)]
pub enum CredentialStatus {
    #[default]
    Active,
    Expired,
    Revoked,
}

#[derive(Drop, starknet::Store, Serde, Clone)]
pub struct CredentialMetadata {
    pub issuer: ContractAddress,
    pub issuance_date: u64,
    pub expiration_date: u64,
    pub status: CredentialStatus,
    pub schema_id: felt252,
    pub credential_type: felt252,
    pub level: u8,
    pub renewable: bool,
}

#[derive(Drop, Serde, Clone)]
pub struct BatchMintRequest {
    pub recipient: ContractAddress,
    pub token_id: u256,
    pub token_uri: ByteArray,
    pub expiration_date: u64,
    pub schema_id: felt252,
    pub credential_type: felt252,
    pub level: u8,
    pub renewable: bool,
}

#[starknet::interface]
pub trait ICredenzaCredential<TContractState> {
    fn mint(
        ref self: TContractState,
        recipient: ContractAddress,
        token_id: u256,
        token_uri: ByteArray,
        expiration_date: u64,
        schema_id: felt252
    );

    fn mint_with_details(
        ref self: TContractState,
        recipient: ContractAddress,
        token_id: u256,
        token_uri: ByteArray,
        expiration_date: u64,
        schema_id: felt252,
        credential_type: felt252,
        level: u8,
        renewable: bool
    );

    fn revoke(ref self: TContractState, token_id: u256);
    fn revoke_with_reason(ref self: TContractState, token_id: u256, reason: felt252);

    fn is_expired(self: @TContractState, token_id: u256) -> bool;
    fn is_valid(self: @TContractState, token_id: u256) -> bool;
    fn renew_credential(ref self: TContractState, token_id: u256, new_expiration: u64);

    fn get_credential_metadata(self: @TContractState, token_id: u256) -> CredentialMetadata;
    fn get_credential_status(self: @TContractState, token_id: u256) -> CredentialStatus;
    fn get_credential_schema(self: @TContractState, token_id: u256) -> felt252;
    fn update_metadata(ref self: TContractState, token_id: u256, new_uri: ByteArray);

    fn batch_mint(ref self: TContractState, requests: Array<BatchMintRequest>);
    fn batch_revoke(ref self: TContractState, token_ids: Array<u256>);
    fn get_user_credentials(
        self: @TContractState, 
        user: ContractAddress, 
        offset: u32, 
        limit: u32
    ) -> Array<u256>;

    fn get_credentials_by_schema(
        self: @TContractState, 
        schema_id: felt252, 
        offset: u32, 
        limit: u32
    ) -> Array<u256>;

    fn get_active_credential_count(self: @TContractState, user: ContractAddress) -> u32;
    fn has_credential_type(self: @TContractState, user: ContractAddress, credential_type: felt252) -> bool;

    fn set_issuer_permissions(
        ref self: TContractState, 
        issuer: ContractAddress, 
        can_mint: bool, 
        can_revoke: bool
    );
    fn can_issuer_mint(self: @TContractState, issuer: ContractAddress) -> bool;

    fn update_issuer_registry(ref self: TContractState, new_registry: ContractAddress);
} 