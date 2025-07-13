#[starknet::component]
pub mod CredenzaComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::interfaces::credenza::{
        ApplicantAccepted, ApplicantRejected, CredentialContractCreated, CredentialIssued,
        HolderRevoked, HolderValidated, ICredenza, Job, JobApplied, JobCreated, JobEdit, JobEdited,
        JobNode, JobParams, JobStatus,
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
        ApplicantAccepted: ApplicantAccepted,
        ApplicantRejected: ApplicantRejected,
        HolderValidated: HolderValidated,
        HolderRevoked: HolderRevoked,
        CredentialIssued: CredentialIssued,
        CredentialContractCreated: CredentialContractCreated,
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

            let id = self.nonce.read() + 1;
            let job = self.jobs.entry(id);
            let title_clone = job_params.title.clone();
            job.title.write(title_clone);
            job.details.write(job_params.details);
            job.recruiter.write(caller);
            job.verification.write(Verification::Pending);
            job.created_at.write(get_block_timestamp());
            job.job_status.write(JobStatus::Open);
            job.compensation.write(job_params.compensation);

            self.job_count.write(self.job_count.read() + 1);
            self.emit(JobCreated { job_id: id, recruiter: caller, title: job_params.title });

            self.nonce.write(id);
            id
        }
        fn edit_job(ref self: ComponentState<TContractState>, edit: JobEdit) {
            self.emit(JobEdited { job_id: edit.job_id });
        }
        fn get_job(self: @ComponentState<TContractState>, id: u256) -> Job {
            Default::default()
        }
        fn get_all_jobs(self: @ComponentState<TContractState>, filter: u8) -> Span<Job> {
            array![].span()
        }
        fn apply(ref self: ComponentState<TContractState>, id: u256, any: ByteArray) {
            let applicant = get_caller_address();
            self.emit(JobApplied { job_id: id, applicant });
        }
        fn get_jobs_by_ids(self: @ComponentState<TContractState>, ids: Array<u256>) -> Span<Job> {
            array![].span()
        }
        // for now, all user details are not hidden.

        // fn get_applicants(self: @ComponentState<TContractState>, id: u256) -> Span<User>;
        fn get_applicants(self: @ComponentState<TContractState>, id: u256) -> Span<User> {
            array![].span()
        }

        // Implements an accept, and an accept_if.
        fn accept(ref self: ComponentState<TContractState>, id: u256, any: ContractAddress) {
            self.emit(ApplicantAccepted { job_id: id, applicant: any });
        }
        fn reject(ref self: ComponentState<TContractState>, id: u256, any: ContractAddress) {
            self.emit(ApplicantRejected { job_id: id, applicant: any });
        }

        fn validate_holder(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) {
            let validator = get_caller_address();
            self.emit(HolderValidated { credential_address: address, holder, validator });
        }
        fn revoke_holder(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) {
            let revoker = get_caller_address();
            self.emit(HolderRevoked { credential_address: address, holder, revoker });
        }
        fn is_holder_validated(
            self: @ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) -> bool {
            false
        }
        // when using this function, there won't be any need for verification.
        fn issue(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            target: ContractAddress,
        ) {
            let issuer = get_caller_address();
            self.emit(CredentialIssued { credential_address: address, target, issuer });
        }

        fn new_credential(ref self: ComponentState<TContractState>) {
            let owner = get_caller_address();
            self
                .emit(
                    CredentialContractCreated { credential_address: 0.try_into().unwrap(), owner },
                );
        }
    }
}
