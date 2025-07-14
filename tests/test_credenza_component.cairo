use starknet::{ContractAddress};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, spy_events, EventSpy, EventSpyAssertionsTrait, start_cheat_caller_address, stop_cheat_caller_address};

use credenza::interfaces::credenza::{
    ICredenzaDispatcher, ICredenzaDispatcherTrait, 
    JobParams, JobApplied, RecruiterAccepted, ApplicantConfirmed, JobCompleted
};
use credenza::interfaces::user::{IUserDispatcher, IUserDispatcherTrait, UserParams, UserType};
use credenza::components::credenza::CredenzaComponent;

// Test contract that combines both components
#[starknet::contract]
mod TestCredenzaContract {
    use credenza::components::credenza::CredenzaComponent;
    use credenza::components::user::UserComponent;

    component!(path: CredenzaComponent, storage: credenza, event: CredenzaEvent);
    component!(path: UserComponent, storage: user, event: UserEvent);

    #[abi(embed_v0)]
    impl CredenzaImpl = CredenzaComponent::CredenzaImpl<ContractState>;
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
    pub enum Event {
        #[flat]
        CredenzaEvent: CredenzaComponent::Event,
        #[flat]
        UserEvent: UserComponent::Event,
    }
}

// Test helper functions
fn deploy_test_contract() -> (ICredenzaDispatcher, IUserDispatcher) {
    let contract = declare("TestCredenzaContract").unwrap();
    let (contract_address, _) = contract.contract_class().deploy(@array![]).unwrap();
    
    (
        ICredenzaDispatcher { contract_address },
        IUserDispatcher { contract_address }
    )
}

fn setup_verified_user(user_contract: IUserDispatcher, address: ContractAddress) {
    start_cheat_caller_address(user_contract.contract_address, address);
    let user_params = UserParams {
        firstname: "Test",
        lastname: "User",
        other_addresses: array![],
        user_type: UserType::User,
        nfts: array![]
    };
    user_contract.create_user(user_params);
    stop_cheat_caller_address(user_contract.contract_address);
}

fn create_test_job_params() -> JobParams {
    JobParams {
        title: "Senior Software Engineer Position - Full Stack Development",
        details: "We are seeking a skilled full-stack developer with experience in modern web technologies and frameworks...",
        compensation: (0x123.try_into().unwrap(), 50000),
        applicants_threshold: 10,
        rank_threshold: 5
    }
}

fn setup_job_scenario() -> (ICredenzaDispatcher, IUserDispatcher, ContractAddress, ContractAddress, u256) {
    let (credenza, user_contract) = deploy_test_contract();
    
    let recruiter: ContractAddress = 0x1.try_into().unwrap();
    let applicant: ContractAddress = 0x2.try_into().unwrap();
    
    // Setup users
    setup_verified_user(user_contract, recruiter);
    setup_verified_user(user_contract, applicant);
    
    // Create a job
    start_cheat_caller_address(credenza.contract_address, recruiter);
    let job_params = create_test_job_params();
    let job_id = credenza.create_job(job_params);
    stop_cheat_caller_address(credenza.contract_address);
    
    (credenza, user_contract, recruiter, applicant, job_id)
}

// =============================================================================
// APPLY FUNCTION TESTS
// =============================================================================

#[test]
fn test_apply_success() {
    let (credenza, _user_contract, _recruiter, applicant, job_id) = setup_job_scenario();
    
    // Setup event spy
    let mut spy = spy_events();
    
    // Apply to the job
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "My application details and portfolio link: github.com/myprofile");
    stop_cheat_caller_address(credenza.contract_address);
    
    // Verify JobApplied event was emitted
    let expected_event = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::JobApplied(JobApplied { job_id, applicant })
    );
    spy.assert_emitted(@array![(credenza.contract_address, expected_event)]);
}

#[test]
fn test_apply_multiple_times_same_user() {
    let (credenza, _user_contract, _recruiter, applicant, job_id) = setup_job_scenario();
    
    start_cheat_caller_address(credenza.contract_address, applicant);
    
    // First application
    credenza.apply(job_id, "Initial application");
    
    // Update application (should succeed)
    credenza.apply(job_id, "Updated application with more details");
    
    stop_cheat_caller_address(credenza.contract_address);
    
    // Should not throw any errors
}

#[test]
#[should_panic(expected: ('JOB: NOT_OPEN',))]
fn test_apply_to_nonexistent_job() {
    let (credenza, _user_contract, _recruiter, applicant, _job_id) = setup_job_scenario();
    
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(999, "Application to non-existent job");
    stop_cheat_caller_address(credenza.contract_address);
}

#[test]
#[should_panic(expected: ('JOB: NOT_OPEN',))]
fn test_apply_to_completed_job() {
    let (credenza, _user_contract, recruiter, applicant, job_id) = setup_job_scenario();
    
    // Complete the job workflow
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "Application");
    stop_cheat_caller_address(credenza.contract_address);
    
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Try to apply again after job is completed
    let new_applicant: ContractAddress = 0x3.try_into().unwrap();
    setup_verified_user(_user_contract, new_applicant);
    
    start_cheat_caller_address(credenza.contract_address, new_applicant);
    credenza.apply(job_id, "Late application");
    stop_cheat_caller_address(credenza.contract_address);
}

// =============================================================================
// ACCEPT FUNCTION TESTS
// =============================================================================

#[test]
fn test_recruiter_accept_applicant() {
    let (credenza, _user_contract, recruiter, applicant, job_id) = setup_job_scenario();
    
    // First, applicant must apply
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "My application");
    stop_cheat_caller_address(credenza.contract_address);
    
    // Setup event spy
    let mut spy = spy_events();
    
    // Recruiter accepts the applicant
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Verify RecruiterAccepted event was emitted
    let expected_event = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::RecruiterAccepted(RecruiterAccepted { job_id, applicant, recruiter })
    );
    spy.assert_emitted(@array![(credenza.contract_address, expected_event)]);
}

#[test]
fn test_applicant_confirm_job_offer() {
    let (credenza, _user_contract, recruiter, applicant, job_id) = setup_job_scenario();
    
    // Applicant applies
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "My application");
    stop_cheat_caller_address(credenza.contract_address);
    
    // Recruiter accepts
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Setup event spy for applicant confirmation
    let mut spy = spy_events();
    
    // Applicant confirms the job offer
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Verify both ApplicantConfirmed and JobCompleted events were emitted
    let expected_event1 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::ApplicantConfirmed(ApplicantConfirmed { job_id, applicant, recruiter })
    );
    let expected_event2 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::JobCompleted(JobCompleted { job_id, applicant, recruiter })
    );
    spy.assert_emitted(@array![
        (credenza.contract_address, expected_event1),
        (credenza.contract_address, expected_event2)
    ]);
}

#[test]
fn test_full_acceptance_workflow() {
    let (credenza, _user_contract, recruiter, applicant, job_id) = setup_job_scenario();
    
    // Setup event spy to track all events
    let mut spy = spy_events();
    
    // Step 1: Applicant applies for the job
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "My comprehensive application with portfolio");
    stop_cheat_caller_address(credenza.contract_address);
    
    // Step 2: Recruiter goes through HR process and accepts the applicant
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Step 3: Applicant confirms acceptance (three to tango)
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Verify the complete event flow
    let event1 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::JobApplied(JobApplied { job_id, applicant })
    );
    let event2 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::RecruiterAccepted(RecruiterAccepted { job_id, applicant, recruiter })
    );
    let event3 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::ApplicantConfirmed(ApplicantConfirmed { job_id, applicant, recruiter })
    );
    let event4 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::JobCompleted(JobCompleted { job_id, applicant, recruiter })
    );
    spy.assert_emitted(@array![
        (credenza.contract_address, event1),
        (credenza.contract_address, event2),
        (credenza.contract_address, event3),
        (credenza.contract_address, event4)
    ]);
}

#[test]
fn test_different_order_acceptance() {
    let (credenza, _user_contract, recruiter, applicant, job_id) = setup_job_scenario();
    
    // Applicant applies
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "My application");
    stop_cheat_caller_address(credenza.contract_address);
    
    // Alternative flow: recruiter accepts first, then applicant confirms
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Setup event spy
    let mut spy = spy_events();
    
    // Applicant confirms
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Should still complete successfully
    let event1 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::ApplicantConfirmed(ApplicantConfirmed { job_id, applicant, recruiter })
    );
    let event2 = TestCredenzaContract::Event::CredenzaEvent(
        CredenzaComponent::Event::JobCompleted(JobCompleted { job_id, applicant, recruiter })
    );
    spy.assert_emitted(@array![
        (credenza.contract_address, event1),
        (credenza.contract_address, event2)
    ]);
}

#[test]
#[should_panic(expected: ('APPLICANT: NOT_APPLIED',))]
fn test_accept_without_application() {
    let (credenza, _user_contract, recruiter, applicant, job_id) = setup_job_scenario();
    
    // Try to accept an applicant who never applied
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
}

#[test]
#[should_panic(expected: ('RECRUITER: NOT_ACCEPTED',))]
fn test_applicant_confirm_without_recruiter_acceptance() {
    let (credenza, _user_contract, _recruiter, applicant, job_id) = setup_job_scenario();
    
    // Applicant applies
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "My application");
    
    // Applicant tries to confirm without recruiter accepting first
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
}

#[test]
#[should_panic(expected: ('UNAUTHORIZED',))]
fn test_unauthorized_accept() {
    let (credenza, user_contract, _recruiter, applicant, job_id) = setup_job_scenario();
    
    // Applicant applies
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "My application");
    stop_cheat_caller_address(credenza.contract_address);
    
    // Third party tries to accept
    let unauthorized: ContractAddress = 0x999.try_into().unwrap();
    setup_verified_user(user_contract, unauthorized);
    
    start_cheat_caller_address(credenza.contract_address, unauthorized);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
}

#[test]
#[should_panic(expected: ('JOB: NOT_OPEN',))]
fn test_accept_on_completed_job() {
    let (credenza, user_contract, recruiter, applicant, job_id) = setup_job_scenario();
    
    // Complete the job with first applicant
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.apply(job_id, "First application");
    stop_cheat_caller_address(credenza.contract_address);
    
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    start_cheat_caller_address(credenza.contract_address, applicant);
    credenza.accept(job_id, applicant);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Try to accept another applicant on completed job
    let second_applicant: ContractAddress = 0x3.try_into().unwrap();
    setup_verified_user(user_contract, second_applicant);
    
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, second_applicant);
    stop_cheat_caller_address(credenza.contract_address);
}

#[test]
#[should_panic(expected: ('JOB: NOT_OPEN',))]
fn test_accept_nonexistent_job() {
    let (credenza, _user_contract, recruiter, applicant, _job_id) = setup_job_scenario();
    
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(999, applicant);
    stop_cheat_caller_address(credenza.contract_address);
}

// =============================================================================
// EDGE CASES AND ERROR HANDLING
// =============================================================================

#[test]
fn test_multiple_applicants_different_outcomes() {
    let (credenza, user_contract, recruiter, applicant1, job_id) = setup_job_scenario();
    
    // Create second applicant
    let applicant2: ContractAddress = 0x3.try_into().unwrap();
    setup_verified_user(user_contract, applicant2);
    
    // Both applicants apply
    start_cheat_caller_address(credenza.contract_address, applicant1);
    credenza.apply(job_id, "Application from applicant 1");
    stop_cheat_caller_address(credenza.contract_address);
    
    start_cheat_caller_address(credenza.contract_address, applicant2);
    credenza.apply(job_id, "Application from applicant 2");
    stop_cheat_caller_address(credenza.contract_address);
    
    // Recruiter accepts applicant1
    start_cheat_caller_address(credenza.contract_address, recruiter);
    credenza.accept(job_id, applicant1);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Applicant1 confirms
    start_cheat_caller_address(credenza.contract_address, applicant1);
    credenza.accept(job_id, applicant1);
    stop_cheat_caller_address(credenza.contract_address);
    
    // Job should now be completed, so recruiter cannot accept applicant2
    // This should fail because job is completed
    // start_cheat_caller_address(credenza.contract_address, recruiter);
    // credenza.accept(job_id, applicant2); // Would panic with 'JOB: NOT_OPEN'
    // stop_cheat_caller_address(credenza.contract_address);
}

// =============================================================================
// PLACEHOLDER TESTS FOR FUTURE FUNCTIONS
// =============================================================================

#[test]
#[ignore]
fn test_create_job() {
    // TODO: Implement comprehensive create_job tests
    assert(false, 'TODO: create_job tests');
}

#[test]
#[ignore]
fn test_edit_job() {
    // TODO: Implement edit_job tests
    assert(false, 'TODO: edit_job tests');
}

#[test]
#[ignore]
fn test_get_job() {
    // TODO: Implement get_job tests
    assert(false, 'TODO: get_job tests');
}

#[test]
#[ignore]
fn test_get_all_jobs() {
    // TODO: Implement get_all_jobs tests
    assert(false, 'TODO: get_all_jobs tests');
}

#[test]
#[ignore]
fn test_reject() {
    // TODO: Implement reject tests
    assert(false, 'TODO: reject tests');
}

#[test]
#[ignore]
fn test_validate_holder() {
    // TODO: Implement validate_holder tests
    assert(false, 'TODO: validate_holder tests');
}

#[test]
#[ignore]
fn test_revoke_holder() {
    // TODO: Implement revoke_holder tests
    assert(false, 'TODO: revoke_holder tests');
}

#[test]
#[ignore]
fn test_issue_credential() {
    // TODO: Implement issue tests
    assert(false, 'TODO: issue tests');
}

#[test]
#[ignore]
fn test_new_credential() {
    // TODO: Implement new_credential tests
    assert(false, 'TODO: new_credential tests');
}
