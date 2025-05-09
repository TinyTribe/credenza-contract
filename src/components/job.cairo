#[starknet::component]
pub mod JobComponent {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::job::{IJob, Job, JobEdit, JobNode, JobParams, UserParams};

    #[storage]
    pub struct Storage {
        jobs: Map<ContractAddress, JobNode>,
        job_count: u256,
    }

    #[embeddable_as(JobImpl)]
    pub impl JobCompImpl<
        TContractState, +HasComponent<TContractState>,
    > of IJob<ComponentState<TContractState>> {
        fn create_job(ref self: ComponentState<TContractState>, job_params: JobParams) -> u64 {
            0
        }

        fn edit_job(ref self: ComponentState<TContractState>, edit: JobEdit) {}

        fn get_job(self: @ComponentState<TContractState>, id: u64) -> Job {
            Default::default()
        }

        fn get_all_jobs(self: @ComponentState<TContractState>, filter: u8) -> Span<Job> {
            array![].span()
        }
    }
}
