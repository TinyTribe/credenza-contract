// TODO: Might be moved from core, and might be renamed.

#[starknet::interface]
pub trait IJob<TContractState> {
    fn create_job(ref self: TContractState, job_params: JobParams) -> u64;
    fn edit_job(ref self: TContractState, edit: JobEdit);
    fn get_job(self: @TContractState, id: u64) -> Job;
    fn get_all_jobs(self: @TContractState, filter: u8) -> Span<Job>;
}

#[starknet::interface]
pub trait IUser<TContractState> {
    fn create_user(ref self: TContractState, user_params: UserParams);
}

#[derive(Drop, Copy, Serde, Default)]
pub struct Job {
    pub name: felt252,
}

#[derive(Drop, Copy, Serde, Default)]
pub struct JobEdit {
    pub name: felt252,
}

#[derive(Drop, Copy, Serde, Default)]
pub struct JobParams {
    pub name: felt252,
}

#[starknet::storage_node]
pub struct JobNode {}

#[derive(Drop, Copy, Serde, Default)]
pub struct UserParams {}
