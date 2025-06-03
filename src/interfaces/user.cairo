use starknet::ContractAddress;
use starknet::storage::Map;
use crate::utils::base::{ContractAddressDefault, Verification};

#[starknet::interface]
pub trait IUser<TContractState> {
    fn create_user(ref self: TContractState, user_params: UserParams);
}

#[derive(Drop, Clone, Serde, Default)]
pub struct UserParams {
    pub fname: ByteArray,
    pub lastname: ByteArray,
    pub other_addresses: Array<
        ContractAddress,
    > // to be verified. Till then, any credential owned by these addresses are pending.
}

#[starknet::storage_node]
pub struct User {
    pub verification: Verification,
    pub credentials: Map<ContractAddress, Credentials>,
}

#[derive(Drop, Default, Copy, Serde, starknet::Store)]
pub struct Credentials {
    pub is_verfied: bool,
    pub issued: Issued,
}

// This architecture is what I can think of currently
// it might be later refactored to be more singular.
#[derive(Drop, Copy, PartialEq, Serde, Default, starknet::Store)]
pub enum Issued {
    #[default]
    Undefined,
    By: ContractAddress,
    To: ContractAddress,
}
