#[starknet::component]
pub mod CredenzaComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::interfaces::credenza::{
        CredentialIssued, HolderRevoked, HolderValidated, ICredenza, Job, JobAccepted, JobApplied,
        JobCreated, JobEdit, JobEdited, JobNode, JobParams, JobRejected, JobStatus,
        NewCredentialCreated,
    };
    use crate::interfaces::user::User;
    use crate::utils::base::Verification;
    use super::super::user::UserComponent;

    #[storage]
    pub struct Storage {
        jobs: Map<u256, JobNode>,
        job_count: u256,
        nonce: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        JobCreated: JobCreated,
        JobEdited: JobEdited,
        JobApplied: JobApplied,
        JobAccepted: JobAccepted,
        JobRejected: JobRejected,
        HolderValidated: HolderValidated,
        HolderRevoked: HolderRevoked,
        CredentialIssued: CredentialIssued,
        NewCredentialCreated: NewCredentialCreated,
    }

    #[embeddable_as(CredenzaImpl)]
    pub impl Credenza<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl UserComp: UserComponent::HasComponent<TContractState>,
    > of ICredenza<ComponentState<TContractState>> {
        fn create_job(ref self: ComponentState<TContractState>, job_params: JobParams) -> u256 {
            let caller = get_caller_address();
            let userc = get_dep_component!(@self, UserComp);
            let verification = userc.users.entry(caller).verification.read();
            assert(verification == Verification::Passed, 'UNVERIFIED USER');
            assert(job_params.title.len() > 10, 'TITLE INSUFFICIENT');
            assert(job_params.details.len() > 40, 'DETAILS INSUFFICIENT');

            let id = self.nonce.read() + 1_u256;
            let job = self.jobs.entry(id);
            job.title.write(job_params.title.clone());
            job.details.write(job_params.details.clone());
            job.recruiter.write(caller);
            job.verification.write(Verification::Pending);
            job.created_at.write(get_block_timestamp());
            job.job_status.write(JobStatus::Open);
            job.compensation.write(job_params.compensation);

            self.job_count.write(self.job_count.read() + 1);
            self
                .emit(
                    Event::JobCreated(
                        JobCreated {
                            id,
                            recruiter: caller,
                            title: job_params.title,
                            details: job_params.details,
                            compensation: job_params.compensation,
                        },
                    ),
                );
            self.nonce.write(id);
            id
        }
        fn edit_job(ref self: ComponentState<TContractState>, id: u256, edit: JobEdit) {
            let caller = get_caller_address();
            self.emit(Event::JobEdited(JobEdited { id, editor: caller, new_title: edit.title }));
        }
        fn get_job(self: @ComponentState<TContractState>, id: u256) -> Job {
            Default::default()
        }
        fn get_all_jobs(self: @ComponentState<TContractState>, filter: u8) -> Span<Job> {
            array![].span()
        }
        fn apply(ref self: ComponentState<TContractState>, id: u256, any: ByteArray) {
            let caller = get_caller_address();
            self.emit(Event::JobApplied(JobApplied { id, applicant: caller, data: any }));
        }
        fn get_jobs_by_ids(self: @ComponentState<TContractState>, ids: Array<u256>) -> Span<Job> {
            array![].span()
        }
        fn get_applicants(self: @ComponentState<TContractState>, id: u256) -> Span<User> {
            array![].span()
        }
        fn accept(ref self: ComponentState<TContractState>, id: u256, any: ContractAddress) {
            let caller = get_caller_address();
            self.emit(Event::JobAccepted(JobAccepted { id, recruiter: caller, applicant: any }));
        }
        fn reject(ref self: ComponentState<TContractState>, id: u256, any: ContractAddress) {
            let caller = get_caller_address();
            self.emit(Event::JobRejected(JobRejected { id, recruiter: caller, applicant: any }));
        }
        fn validate_holder(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) {
            let caller = get_caller_address();
            self
                .emit(
                    Event::HolderValidated(HolderValidated { address, holder, validator: caller }),
                );
        }
        fn revoke_holder(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) {
            let caller = get_caller_address();
            self.emit(Event::HolderRevoked(HolderRevoked { address, holder, revoker: caller }));
        }
        fn is_holder_validated(
            self: @ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) -> bool {
            false
        }
        fn issue(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            target: ContractAddress,
        ) {
            let caller = get_caller_address();
            self
                .emit(
                    Event::CredentialIssued(CredentialIssued { address, target, issuer: caller }),
                );
        }
        fn new_credential(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            self.emit(Event::NewCredentialCreated(NewCredentialCreated { creator: caller }));
        }
    }
}
