// TODO: Might be moved from core, and might be renamed.
use core::byte_array::ByteArray;
use credenza::interfaces::user::User;
use starknet::ContractAddress;
use starknet::storage::Map;
use crate::utils::base::{ContractAddressDefault, Verification};

#[starknet::interface]
pub trait ICredenza<TContractState> {
    fn create_job(ref self: TContractState, job_params: JobParams) -> u256;
    fn edit_job(ref self: TContractState, id: u256, edit: JobEdit);
    fn get_job(self: @TContractState, id: u256) -> Job;
    fn get_all_jobs(self: @TContractState, filter: u8) -> Span<Job>;
    fn apply(ref self: TContractState, id: u256, any: ByteArray);
    fn get_jobs_by_ids(self: @TContractState, ids: Array<u256>) -> Span<Job>;
    // for now, all user details are not hidden.
    fn get_applicants(self: @TContractState, id: u256) -> Span<User>;

    // Implements an accept, and an accept_if.
    fn accept(ref self: TContractState, id: u256, any: ContractAddress);
    fn reject(ref self: TContractState, id: u256, any: ContractAddress);

    fn validate_holder(ref self: TContractState, address: ContractAddress, holder: ContractAddress);
    fn revoke_holder(ref self: TContractState, address: ContractAddress, holder: ContractAddress);
    fn is_holder_validated(
        self: @TContractState, address: ContractAddress, holder: ContractAddress,
    ) -> bool;
    // when using this function, there won't be any need for verification.
    fn issue(ref self: TContractState, address: ContractAddress, target: ContractAddress);
    // this just deploys a new credential with details
    // some things might be checked like the caller being existent and being verified.
    // add new parameters to this, used for deploying either an erc721 or an SBT.
    fn new_credential(ref self: TContractState);
}

#[derive(Drop, Copy, Serde, Default)]
pub struct Job {
    pub title: felt252,
    pub recruiter: ContractAddress,
    pub verification: Verification,
    pub created_at: u64,
    pub job_status: JobStatus,
}

#[derive(Drop, Copy, Serde, Default, starknet::Store)]
pub enum JobStatus {
    #[default]
    None,
    Open,
    OnHold,
    InProgress,
    Completed,
}

#[derive(Drop, Copy, Serde, Default)]
pub enum JobType {
    #[default]
    FullTime,
    PartTime,
    Contract,
}

#[derive(Drop, Copy, Serde, Default)]
pub struct JobEdit {
    // incoming.
    pub title: felt252,
}

#[derive(Drop, Clone, Serde, Default)]
pub struct JobParams {
    pub title: ByteArray,
    pub details: ByteArray,
    pub compensation: (ContractAddress, u256),
    pub applicants_threshold: u256,
    pub rank_threshold: u256 // if applicable
}

#[starknet::storage_node]
pub struct JobNode {
    pub title: ByteArray,
    pub details: ByteArray,
    pub recruiter: ContractAddress,
    pub verification: Verification,
    pub created_at: u64,
    pub job_status: JobStatus,
    pub compensation: (ContractAddress, u256),
    pub applicant_count: u256,
    pub applicants: Map<ContractAddress, bool>,
    pub is_blacklisted: bool,
}

// Event structs for each function
#[derive(Drop, starknet::Event)]
pub struct JobCreated {
    pub id: u256,
    pub recruiter: ContractAddress,
    pub title: ByteArray,
    pub details: ByteArray,
    pub compensation: (ContractAddress, u256),
}
#[derive(Drop, starknet::Event)]
pub struct JobEdited {
    pub id: u256,
    pub editor: ContractAddress,
    pub new_title: felt252,
}
#[derive(Drop, starknet::Event)]
pub struct JobFetched {
    pub id: u256,
    pub requester: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct AllJobsFetched {
    pub filter: u8,
    pub requester: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct JobApplied {
    pub id: u256,
    pub applicant: ContractAddress,
    pub data: ByteArray,
}
#[derive(Drop, starknet::Event)]
pub struct JobsByIdsFetched {
    pub ids: Array<u256>,
    pub requester: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct ApplicantsFetched {
    pub id: u256,
    pub requester: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct JobAccepted {
    pub id: u256,
    pub recruiter: ContractAddress,
    pub applicant: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct JobRejected {
    pub id: u256,
    pub recruiter: ContractAddress,
    pub applicant: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct HolderValidated {
    pub address: ContractAddress,
    pub holder: ContractAddress,
    pub validator: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct HolderRevoked {
    pub address: ContractAddress,
    pub holder: ContractAddress,
    pub revoker: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct HolderValidationChecked {
    pub address: ContractAddress,
    pub holder: ContractAddress,
    pub checker: ContractAddress,
    pub result: bool,
}
#[derive(Drop, starknet::Event)]
pub struct CredentialIssued {
    pub address: ContractAddress,
    pub target: ContractAddress,
    pub issuer: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct NewCredentialCreated {
    pub creator: ContractAddress,
}
