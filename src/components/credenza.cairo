#[starknet::component]
pub mod CredenzaComponent {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::credenza::{ICredenza, Job, JobEdit, JobNode, JobParams};
    use crate::interfaces::user::User;

    #[storage]
    pub struct Storage {
        jobs: Map<ContractAddress, JobNode>,
        job_count: u256,
    }

    #[embeddable_as(CredenzaImpl)]
    pub impl Credenza<
        TContractState, +HasComponent<TContractState>,
    > of ICredenza<ComponentState<TContractState>> {
        fn create_job(ref self: ComponentState<TContractState>, job_params: JobParams) -> u256 {
            0
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
