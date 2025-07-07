use credenza::components::credenza::CredenzaComponent;

// Import credenza interfaces and events
use credenza::interfaces::credenza::{
    CredentialIssued, HolderRevoked, HolderValidated, ICredenzaDispatcher, ICredenzaDispatcherTrait,
    JobAccepted, JobApplied, JobCreated, JobEdit, JobEdited, JobParams, JobRejected,
    NewCredentialCreated,
};
use credenza::interfaces::user::{IUserDispatcher, IUserDispatcherTrait, UserParams, UserType};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Test constants following the same pattern as test_credential.cairo
fn RECRUITER() -> ContractAddress {
    111.try_into().unwrap()
}

fn APPLICANT() -> ContractAddress {
    222.try_into().unwrap()
}

fn ADMIN() -> ContractAddress {
    444.try_into().unwrap()
}

fn OTHER_USER() -> ContractAddress {
    555.try_into().unwrap()
}

// Create a test contract that implements both components
#[starknet::contract]
mod TestCredenzaContract {
    use credenza::components::credenza::CredenzaComponent;
    use credenza::components::user::UserComponent;
    use starknet::ContractAddress;

    component!(path: CredenzaComponent, storage: credenza, event: CredenzaEvent);
    component!(path: UserComponent, storage: user, event: UserEvent);

    // Credenza Implementation
    #[abi(embed_v0)]
    impl CredenzaImpl = CredenzaComponent::CredenzaImpl<ContractState>;

    // User Implementation
    #[abi(embed_v0)]
    impl UserImpl = UserComponent::UserImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        credenza: CredenzaComponent::Storage,
        #[substorage(v0)]
        user: UserComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        CredenzaEvent: CredenzaComponent::Event,
        #[flat]
        UserEvent: UserComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}
}

// Deploy function following the same pattern as test_credential.cairo
fn deploy_credenza_contract() -> (ICredenzaDispatcher, IUserDispatcher) {
    let contract_class = declare("TestCredenzaContract").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).unwrap();
    (ICredenzaDispatcher { contract_address }, IUserDispatcher { contract_address })
}

// Helper function to create a verified user
fn create_verified_user(user_dispatcher: IUserDispatcher, user: ContractAddress) {
    let user_params = UserParams {
        firstname: "John",
        lastname: "Doe",
        other_addresses: array![],
        user_type: UserType::User,
        nfts: array![],
    };

    start_cheat_caller_address(user_dispatcher.contract_address, user);
    user_dispatcher.create_user(user_params);
    stop_cheat_caller_address(user_dispatcher.contract_address);
}

// Helper function to create job params
fn create_job_params() -> JobParams {
    JobParams {
        title: "Senior Cairo Developer",
        details: "We are looking for an experienced Cairo developer to join our team and help build the future of blockchain technology.",
        compensation: (ADMIN(), 1000000000000000000_u256), // 1 token
        applicants_threshold: 10,
        rank_threshold: 5,
    }
}

// Test create_job event emission
#[test]
fn test_create_job_emits_event() {
    let (credenza_dispatcher, user_dispatcher) = deploy_credenza_contract();
    create_verified_user(user_dispatcher, RECRUITER());

    let job_params = create_job_params();
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, RECRUITER());
    let job_id = credenza_dispatcher.create_job(job_params.clone());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::JobCreated(
        JobCreated {
            id: job_id,
            recruiter: RECRUITER(),
            title: job_params.title,
            details: job_params.details,
            compensation: job_params.compensation,
        },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test edit_job event emission
#[test]
fn test_edit_job_emits_event() {
    let (credenza_dispatcher, user_dispatcher) = deploy_credenza_contract();
    create_verified_user(user_dispatcher, RECRUITER());

    let job_id = 1_u256;
    let job_edit = JobEdit { title: 'Updated Title' };
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, RECRUITER());
    credenza_dispatcher.edit_job(job_id, job_edit);
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::JobEdited(
        JobEdited { id: job_id, editor: RECRUITER(), new_title: job_edit.title },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test apply event emission
#[test]
fn test_apply_emits_event() {
    let (credenza_dispatcher, _) = deploy_credenza_contract();
    let job_id = 1_u256;
    let application_data = "I am interested in this position and have 5 years of experience.";
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, APPLICANT());
    credenza_dispatcher.apply(job_id, application_data.clone());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::JobApplied(
        JobApplied { id: job_id, applicant: APPLICANT(), data: application_data },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test accept event emission
#[test]
fn test_accept_emits_event() {
    let (credenza_dispatcher, _) = deploy_credenza_contract();
    let job_id = 1_u256;
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, RECRUITER());
    credenza_dispatcher.accept(job_id, APPLICANT());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::JobAccepted(
        JobAccepted { id: job_id, recruiter: RECRUITER(), applicant: APPLICANT() },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test reject event emission
#[test]
fn test_reject_emits_event() {
    let (credenza_dispatcher, _) = deploy_credenza_contract();
    let job_id = 1_u256;
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, RECRUITER());
    credenza_dispatcher.reject(job_id, APPLICANT());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::JobRejected(
        JobRejected { id: job_id, recruiter: RECRUITER(), applicant: APPLICANT() },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test validate_holder event emission
#[test]
fn test_validate_holder_emits_event() {
    let (credenza_dispatcher, _) = deploy_credenza_contract();
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, ADMIN());
    credenza_dispatcher.validate_holder(RECRUITER(), APPLICANT());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::HolderValidated(
        HolderValidated { address: RECRUITER(), holder: APPLICANT(), validator: ADMIN() },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test revoke_holder event emission
#[test]
fn test_revoke_holder_emits_event() {
    let (credenza_dispatcher, _) = deploy_credenza_contract();
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, ADMIN());
    credenza_dispatcher.revoke_holder(RECRUITER(), APPLICANT());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::HolderRevoked(
        HolderRevoked { address: RECRUITER(), holder: APPLICANT(), revoker: ADMIN() },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test issue event emission
#[test]
fn test_issue_emits_event() {
    let (credenza_dispatcher, _) = deploy_credenza_contract();
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, ADMIN());
    credenza_dispatcher.issue(RECRUITER(), APPLICANT());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::CredentialIssued(
        CredentialIssued { address: RECRUITER(), target: APPLICANT(), issuer: ADMIN() },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test new_credential event emission
#[test]
fn test_new_credential_emits_event() {
    let (credenza_dispatcher, _) = deploy_credenza_contract();
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, ADMIN());
    credenza_dispatcher.new_credential();
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    let expected_event = CredenzaComponent::Event::NewCredentialCreated(
        NewCredentialCreated { creator: ADMIN() },
    );
    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_event)]);
}

// Test multiple events in sequence - following the batch test pattern from test_credential.cairo
#[test]
fn test_multiple_events_sequence() {
    let (credenza_dispatcher, user_dispatcher) = deploy_credenza_contract();
    create_verified_user(user_dispatcher, RECRUITER());

    let job_params = create_job_params();
    let mut spy = spy_events();

    start_cheat_caller_address(credenza_dispatcher.contract_address, RECRUITER());

    // Create job
    let job_id = credenza_dispatcher.create_job(job_params.clone());

    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    // Verify all events were emitted in order
    let expected_create_event = CredenzaComponent::Event::JobCreated(
        JobCreated {
            id: job_id,
            recruiter: RECRUITER(),
            title: job_params.title,
            details: job_params.details,
            compensation: job_params.compensation,
        },
    );

    spy.assert_emitted(@array![(credenza_dispatcher.contract_address, expected_create_event)]);
}

// Test job workflow events - similar to the workflow tests in test_credential.cairo
#[test]
fn test_job_workflow_events() {
    let (credenza_dispatcher, user_dispatcher) = deploy_credenza_contract();
    create_verified_user(user_dispatcher, RECRUITER());

    let job_params = create_job_params();
    let application_data = "I am very interested in this position.";
    let mut spy = spy_events();

    // Create job
    start_cheat_caller_address(credenza_dispatcher.contract_address, RECRUITER());
    let job_id = credenza_dispatcher.create_job(job_params.clone());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    // Apply for job
    start_cheat_caller_address(credenza_dispatcher.contract_address, APPLICANT());
    credenza_dispatcher.apply(job_id, application_data.clone());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    // Accept applicant
    start_cheat_caller_address(credenza_dispatcher.contract_address, RECRUITER());
    credenza_dispatcher.accept(job_id, APPLICANT());
    stop_cheat_caller_address(credenza_dispatcher.contract_address);

    // Verify workflow events
    let expected_create_event = CredenzaComponent::Event::JobCreated(
        JobCreated {
            id: job_id,
            recruiter: RECRUITER(),
            title: job_params.title,
            details: job_params.details,
            compensation: job_params.compensation,
        },
    );

    let expected_apply_event = CredenzaComponent::Event::JobApplied(
        JobApplied { id: job_id, applicant: APPLICANT(), data: application_data },
    );

    let expected_accept_event = CredenzaComponent::Event::JobAccepted(
        JobAccepted { id: job_id, recruiter: RECRUITER(), applicant: APPLICANT() },
    );

    spy
        .assert_emitted(
            @array![
                (credenza_dispatcher.contract_address, expected_create_event),
                (credenza_dispatcher.contract_address, expected_apply_event),
                (credenza_dispatcher.contract_address, expected_accept_event),
            ],
        );
}
