// TODO: Might be moved from core, and might be renamed.
use credenza::interfaces::user::User;
use starknet::ContractAddress;
use starknet::storage::Map;
use crate::utils::base::{ContractAddressDefault, Verification};

#[starknet::interface]
pub trait ICredenza<TContractState> {
    fn create_job(ref self: TContractState, job_params: JobParams) -> u256;
    fn edit_job(ref self: TContractState, edit: JobEdit);
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

#[derive(Drop, Copy, Serde, Default, PartialEq, starknet::Store)]
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

#[derive(Drop, Serde, Default)]
pub struct JobEdit {
    pub job_id: u256,
    pub title: Option<ByteArray>,
    pub details: Option<ByteArray>,
    pub compensation: Option<(ContractAddress, u256)>,
    pub applicants_threshold: Option<u256>,
    pub rank_threshold: Option<u256>,
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
    pub recruiter_accepted: Map<ContractAddress, bool>, // recruiter accepts specific applicant
    pub applicant_accepted: Map<ContractAddress, bool>, // applicant accepts the job offer
    pub selected_applicant: ContractAddress, // final selected applicant when both accept
    pub applicants_threshold: u256,
    pub rank_threshold: u256,
}

#[derive(Drop, starknet::Event)]
pub struct JobCreated {
    #[key]
    pub job_id: u256,
    pub recruiter: ContractAddress,
    pub title: ByteArray,
}

#[derive(Drop, starknet::Event)]
pub struct JobEdited {
    #[key]
    pub job_id: u256,
}

#[derive(Drop, starknet::Event)]
pub struct JobApplied {
    #[key]
    pub job_id: u256,
    #[key]
    pub applicant: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ApplicantAccepted {
    #[key]
    pub job_id: u256,
    #[key]
    pub applicant: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ApplicantRejected {
    #[key]
    pub job_id: u256,
    #[key]
    pub applicant: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct HolderValidated {
    #[key]
    pub credential_address: ContractAddress,
    #[key]
    pub holder: ContractAddress,
    pub validator: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct HolderRevoked {
    #[key]
    pub credential_address: ContractAddress,
    #[key]
    pub holder: ContractAddress,
    pub revoker: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct CredentialIssued {
    #[key]
    pub credential_address: ContractAddress,
    #[key]
    pub target: ContractAddress,
    pub issuer: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct CredentialContractCreated {
    #[key]
    pub credential_address: ContractAddress,
    pub owner: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct RecruiterAccepted {
    #[key]
    pub job_id: u256,
    #[key]
    pub applicant: ContractAddress,
    pub recruiter: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ApplicantConfirmed {
    #[key]
    pub job_id: u256,
    #[key]
    pub applicant: ContractAddress,
    pub recruiter: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct JobCompleted {
    #[key]
    pub job_id: u256,
    #[key]
    pub applicant: ContractAddress,
    pub recruiter: ContractAddress,
}
