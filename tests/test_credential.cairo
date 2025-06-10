use core::array::ArrayTrait;
use core::byte_array::ByteArray;
use core::integer::u256;
use credenza::contracts::erc721::CredenzaCredential;
use credenza::contracts::mock_issuer_registry::{
    IMockIssuerRegistryDispatcher, IMockIssuerRegistryDispatcherTrait,
};
use credenza::interfaces::erc721::{
    BatchMintRequest, CredentialStatus, ICredenzaCredentialDispatcher,
    ICredenzaCredentialDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn ISSUER() -> ContractAddress {
    111.try_into().unwrap()
}

fn RECIPIENT() -> ContractAddress {
    222.try_into().unwrap()
}

fn ADMIN() -> ContractAddress {
    444.try_into().unwrap()
}

fn deploy_contracts() -> (ICredenzaCredentialDispatcher, IMockIssuerRegistryDispatcher) {
    let registry_class = declare("MockIssuerRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_class.deploy(@array![]).unwrap();
    let mock_registry_dispatcher = IMockIssuerRegistryDispatcher {
        contract_address: registry_address,
    };

    let nft_class = declare("CredenzaCredential").unwrap().contract_class();
    let mut constructor_args: Array<felt252> = array![];
    registry_address.serialize(ref constructor_args);
    let name: ByteArray = "Credenza Credential";
    let symbol: ByteArray = "CRED";
    name.serialize(ref constructor_args);
    symbol.serialize(ref constructor_args);
    ADMIN().serialize(ref constructor_args);
    let (nft_address, _) = nft_class.deploy(@constructor_args).unwrap();
    let nft_dispatcher = ICredenzaCredentialDispatcher { contract_address: nft_address };

    (nft_dispatcher, mock_registry_dispatcher)
}

#[test]
fn test_mint_with_details() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    let token_id: u256 = 1;
    let token_uri = "ipfs://detailed_credential";
    let expiration_date: u64 = 1000000000;
    let schema_id: felt252 = 'degree_schema';
    let credential_type: felt252 = 'bachelor_degree';
    let level: u8 = 3;
    let renewable = true;

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft
        .mint_with_details(
            RECIPIENT(),
            token_id,
            token_uri,
            expiration_date,
            schema_id,
            credential_type,
            level,
            renewable,
        );
    stop_cheat_caller_address(nft.contract_address);

    let metadata = nft.get_credential_metadata(token_id);
    assert(metadata.credential_type == credential_type, 'Wrong credential type');
    assert(metadata.level == level, 'Wrong level');
    assert(metadata.renewable == renewable, 'Wrong renewable status');
    assert(metadata.schema_id == schema_id, 'Wrong schema ID');
}

#[test]
fn test_expiration_functionality() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    let token_id: u256 = 1;
    let current_time = 1000000000;
    let expiration_time = current_time + 86400;

    start_cheat_block_timestamp(nft.contract_address, current_time);

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft
        .mint_with_details(
            RECIPIENT(),
            token_id,
            "ipfs://expiring",
            expiration_time,
            'temp_cert',
            'temporary',
            1,
            true,
        );
    stop_cheat_caller_address(nft.contract_address);

    assert(nft.is_valid(token_id), 'Should be valid initially');
    assert(!nft.is_expired(token_id), 'Should not be expired initially');
    assert(nft.get_credential_status(token_id) == CredentialStatus::Active, 'Should be active');

    start_cheat_block_timestamp(nft.contract_address, expiration_time + 1);

    assert(!nft.is_valid(token_id), 'Should be invalid after exp');
    assert(nft.is_expired(token_id), 'Should be expired');
    assert(
        nft.get_credential_status(token_id) == CredentialStatus::Expired,
        'Should be expired status',
    );

    stop_cheat_block_timestamp(nft.contract_address);
}

#[test]
fn test_renew_credential() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    let token_id: u256 = 1;
    let current_time = 1000000000;
    let expiration_time = current_time + 86400;
    let new_expiration = current_time + 172800;

    start_cheat_block_timestamp(nft.contract_address, current_time);

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft
        .mint_with_details(
            RECIPIENT(),
            token_id,
            "ipfs://renewable",
            expiration_time,
            'renewable_cert',
            'certification',
            2,
            true,
        );

    let mut spy = spy_events();
    nft.renew_credential(token_id, new_expiration);
    stop_cheat_caller_address(nft.contract_address);

    let metadata = nft.get_credential_metadata(token_id);
    assert(metadata.expiration_date == new_expiration, 'Expiration not updated');

    let expected_event = CredenzaCredential::Event::CredentialRenewed(
        CredenzaCredential::CredentialRenewed {
            token_id, old_expiration: expiration_time, new_expiration, renewed_by: ISSUER(),
        },
    );
    spy.assert_emitted(@array![(nft.contract_address, expected_event)]);

    stop_cheat_block_timestamp(nft.contract_address);
}

#[test]
#[should_panic(expected: 'CREDENTIAL: NOT_RENEWABLE')]
fn test_renew_non_renewable_credential() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    let token_id: u256 = 1;

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft
        .mint_with_details(
            RECIPIENT(),
            token_id,
            "ipfs://non_renewable",
            0,
            'permanent_cert',
            'permanent',
            5,
            false,
        );

    nft.renew_credential(token_id, 1000000000);
    stop_cheat_caller_address(nft.contract_address);
}

#[test]
fn test_batch_mint() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    let mut requests = array![];
    let recipient1: ContractAddress = 100.try_into().unwrap();
    let recipient2: ContractAddress = 200.try_into().unwrap();

    requests
        .append(
            BatchMintRequest {
                recipient: recipient1,
                token_id: 1,
                token_uri: "ipfs://batch1",
                expiration_date: 0,
                schema_id: 'batch_schema',
                credential_type: 'batch_cert',
                level: 1,
                renewable: false,
            },
        );

    requests
        .append(
            BatchMintRequest {
                recipient: recipient2,
                token_id: 2,
                token_uri: "ipfs://batch2",
                expiration_date: 0,
                schema_id: 'batch_schema',
                credential_type: 'batch_cert',
                level: 2,
                renewable: false,
            },
        );

    let mut spy = spy_events();
    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft.batch_mint(requests);
    stop_cheat_caller_address(nft.contract_address);

    let metadata1 = nft.get_credential_metadata(1);
    let metadata2 = nft.get_credential_metadata(2);

    assert(metadata1.issuer == ISSUER(), 'Wrong issuer for token 1');
    assert(metadata2.issuer == ISSUER(), 'Wrong issuer for token 2');
    assert(metadata1.level == 1, 'Wrong level for token 1');
    assert(metadata2.level == 2, 'Wrong level for token 2');

    let expected_event = CredenzaCredential::Event::BatchMinted(
        CredenzaCredential::BatchMinted { issuer: ISSUER(), count: 2, schema_id: 'batch_schema' },
    );
    spy.assert_emitted(@array![(nft.contract_address, expected_event)]);
}

#[test]
fn test_batch_revoke() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft.mint(RECIPIENT(), 1, "ipfs://1", 0, 'schema1');
    nft.mint(RECIPIENT(), 2, "ipfs://2", 0, 'schema2');

    let token_ids = array![1, 2];
    let mut spy = spy_events();
    nft.batch_revoke(token_ids);
    stop_cheat_caller_address(nft.contract_address);

    assert(nft.get_credential_status(1) == CredentialStatus::Revoked, 'Token 1 not revoked');
    assert(nft.get_credential_status(2) == CredentialStatus::Revoked, 'Token 2 not revoked');

    let expected_event = CredenzaCredential::Event::BatchRevoked(
        CredenzaCredential::BatchRevoked { issuer: ISSUER(), count: 2 },
    );
    spy.assert_emitted(@array![(nft.contract_address, expected_event)]);
}

#[test]
fn test_revoke_with_reason() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft.mint(RECIPIENT(), 1, "ipfs://test", 0, 'schema1');

    let mut spy = spy_events();
    nft.revoke_with_reason(1, 'FRAUD_DETECTED');
    stop_cheat_caller_address(nft.contract_address);

    assert(nft.get_credential_status(1) == CredentialStatus::Revoked, 'Token not revoked');

    let expected_event = CredenzaCredential::Event::CredentialRevoked(
        CredenzaCredential::CredentialRevoked {
            token_id: 1, issuer: ISSUER(), reason: 'FRAUD_DETECTED',
        },
    );
    spy.assert_emitted(@array![(nft.contract_address, expected_event)]);
}

#[test]
fn test_schema_getter() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    let schema_id: felt252 = 'test_schema_123';

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft.mint(RECIPIENT(), 1, "ipfs://test", 0, schema_id);
    stop_cheat_caller_address(nft.contract_address);

    assert(nft.get_credential_schema(1) == schema_id, 'Wrong schema returned');
}

#[test]
fn test_metadata_update() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft.mint(RECIPIENT(), 1, "ipfs://original", 0, 'schema1');

    nft.update_metadata(1, "ipfs://updated");
    stop_cheat_caller_address(nft.contract_address);
}

#[test]
#[should_panic(expected: 'CREDENTIAL: INVALID_EXPIRATION')]
fn test_invalid_expiration_date() {
    let (nft, mock_registry) = deploy_contracts();

    start_cheat_caller_address(mock_registry.contract_address, ADMIN());
    mock_registry.set_verified_issuer(ISSUER(), true);
    stop_cheat_caller_address(mock_registry.contract_address);

    let current_time = 1000000000;
    let past_time = current_time - 1000;

    start_cheat_block_timestamp(nft.contract_address, current_time);

    start_cheat_caller_address(nft.contract_address, ISSUER());
    nft.mint_with_details(RECIPIENT(), 1, "ipfs://invalid", past_time, 'schema1', 'cert', 1, false);
    stop_cheat_caller_address(nft.contract_address);
}
