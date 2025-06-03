// TODO: Might be moved from core, and might be renamed.
use starknet::ContractAddress;
use crate::utils::base::{ContractAddressDefault, Verification};

#[starknet::interface]
pub trait ICredenza<TContractState> {
    fn create_job(ref self: TContractState, job_params: JobParams) -> u64;
    fn edit_job(ref self: TContractState, edit: JobEdit);
    fn get_job(self: @TContractState, id: u256) -> Job;
    fn get_all_jobs(self: @TContractState, filter: u8) -> Span<Job>;
    fn apply(ref self: TContractState, id: u256);
    fn get_jobs_by_ids(self: @TContractState, ids: Array<u256>) -> Span<Job>;

    fn verify_holder(ref self: TContractState, address: ContractAddress, holder: ContractAddress);
    // when using this function, there won't be any need for verification.
    fn issue(ref self: TContractState, address: ContractAddress, target: ContractAddress);
}

#[derive(Drop, Copy, Serde, Default)]
pub struct Job {
    pub name: felt252,
    pub recruiter: ContractAddress,
    pub verification: Verification,
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
