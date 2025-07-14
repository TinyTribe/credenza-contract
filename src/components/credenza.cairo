#[starknet::component]
pub mod CredenzaComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::interfaces::credenza::{
        ApplicantAccepted, ApplicantConfirmed, ApplicantRejected, CredentialContractCreated,
        CredentialIssued, HolderRevoked, HolderValidated, ICredenza, Job, JobApplied, JobCompleted,
        JobCreated, JobEdit, JobEdited, JobNode, JobParams, JobStatus, RecruiterAccepted,
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
        RecruiterAccepted: RecruiterAccepted,
        ApplicantConfirmed: ApplicantConfirmed,
        JobCompleted: JobCompleted,
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

            // Check if user is verified
            let userc = get_dep_component!(@self, UserComp);
            let verification = userc.users.entry(applicant).verification.read();
            assert(verification == Verification::Passed, 'UNVERIFIED USER');

            let job = self.jobs.entry(id);

            // Check if job exists and is open
            assert(job.job_status.read() == JobStatus::Open, 'JOB: NOT_OPEN');
            assert(!job.is_blacklisted.read(), 'JOB: BLACKLISTED');

            // Add applicant to job's applicant list
            job.applicants.entry(applicant).write(true);
            job.applicant_count.write(job.applicant_count.read() + 1);

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
            let caller = get_caller_address();

            // Check if caller is verified
            let userc = get_dep_component!(@self, UserComp);
            let verification = userc.users.entry(caller).verification.read();
            assert(verification == Verification::Passed, 'UNVERIFIED USER');

            let job = self.jobs.entry(id);
            let recruiter = job.recruiter.read();

            // Check if job exists and is open
            assert(job.job_status.read() == JobStatus::Open, 'JOB: NOT_OPEN');
            assert(!job.is_blacklisted.read(), 'JOB: BLACKLISTED');

            // Check if the applicant actually applied
            assert(job.applicants.entry(any).read(), 'APPLICANT: NOT_APPLIED');

            if caller == recruiter {
                // Recruiter is accepting the applicant
                job.recruiter_accepted.entry(any).write(true);
                self.emit(RecruiterAccepted { job_id: id, applicant: any, recruiter: caller });

                // Check if applicant has also accepted
                if job.applicant_accepted.entry(any).read() {
                    complete_job_acceptance(ref self, id, any, recruiter);
                }
            } else if caller == any {
                // Applicant is confirming the job offer
                assert(job.recruiter_accepted.entry(any).read(), 'RECRUITER: NOT_ACCEPTED');

                job.applicant_accepted.entry(any).write(true);
                self.emit(ApplicantConfirmed { job_id: id, applicant: any, recruiter });

                // Check if recruiter has also accepted
                if job.recruiter_accepted.entry(any).read() {
                    complete_job_acceptance(ref self, id, any, recruiter);
                }
            } else {
                assert(false, 'UNAUTHORIZED');
            }
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

    // Helper function to complete job acceptance when both parties agree
    fn complete_job_acceptance<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl UserComp: UserComponent::HasComponent<TContractState>,
    >(
        ref self: ComponentState<TContractState>,
        job_id: u256,
        applicant: ContractAddress,
        recruiter: ContractAddress,
    ) {
        let job = self.jobs.entry(job_id);

        // Update job status to completed
        job.job_status.write(JobStatus::Completed);
        job.selected_applicant.write(applicant);

        // Update user's mapped_to field
        let mut user_comp = get_dep_component_mut!(ref self, UserComp);
        user_comp.users.entry(applicant).mapped_to.entry(recruiter).write(true);

        // Emit completion event
        self.emit(JobCompleted { job_id, applicant, recruiter });
    }
}
