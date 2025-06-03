#[starknet::component]
pub mod CredenzaComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::interfaces::credenza::{ICredenza, Job, JobEdit, JobNode, JobParams, JobStatus};
    use crate::interfaces::user::User;
    use crate::utils::base::Verification;
    use super::super::user::UserComponent;

    #[storage]
    pub struct Storage {
        jobs: Map<u256, JobNode>,
        job_count: u256,
        nonce: u256,
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
            job.title.write(job_params.title);
            job.details.write(job_params.details);
            job.recruiter.write(caller);
            job.verification.write(Verification::Pending);
            job.created_at.write(get_block_timestamp());
            job.job_status.write(JobStatus::Open);
            job.compensation.write(job_params.compensation);

            self.job_count.write(self.job_count.read() + 1);
            // emit a JobCreated event here.

            self.nonce.write(id);
            id
        }
        fn edit_job(ref self: ComponentState<TContractState>, edit: JobEdit) {}
        fn get_job(self: @ComponentState<TContractState>, id: u256) -> Job {
            Default::default()
        }
        fn get_all_jobs(self: @ComponentState<TContractState>, filter: u8) -> Span<Job> {
            array![].span()
        }
        fn apply(ref self: ComponentState<TContractState>, id: u256, any: ByteArray) {}
        fn get_jobs_by_ids(self: @ComponentState<TContractState>, ids: Array<u256>) -> Span<Job> {
            array![].span()
        }
        // for now, all user details are not hidden.

        // fn get_applicants(self: @ComponentState<TContractState>, id: u256) -> Span<User>;
        fn get_applicants(self: @ComponentState<TContractState>, id: u256) -> Span<User> {
            array![].span()
        }

        // Implements an accept, and an accept_if.
        fn accept(ref self: ComponentState<TContractState>, id: u256, any: ContractAddress) {}
        fn reject(ref self: ComponentState<TContractState>, id: u256, any: ContractAddress) {}

        fn validate_holder(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) {}
        fn revoke_holder(
            ref self: ComponentState<TContractState>,
            address: ContractAddress,
            holder: ContractAddress,
        ) {}
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
        ) {}

        fn new_credential(ref self: ComponentState<TContractState>) {}
    }
}
