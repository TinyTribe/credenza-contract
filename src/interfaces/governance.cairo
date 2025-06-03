use starknet::ContractAddress;

#[starknet::interface]
pub trait IGovernance<TContractState> {
    // when blacklisting, every job, and user related to this action
    // when blacklisting, funds would be deducted as proof of stake
    // This returns a poll id, people can vote
    // Once the poll succeeds, perhaps above half the calculated threshold, and the defined period
    // of time then validation can commence.
    fn blacklist(ref self: TContractState, target: Target) -> u256;

    // validation takes place by validators/verifiers.
    // - Arguments
    // * `target` The target type and target of this function.
    // * `with_respect_of` matched to a particular poll, if the poll was successful or not
    // TODO: The poll has to have a status, and call count of this function. For a max number of
    // invalid calls, the caller is blacklisted
    // This function requires staking, so funds are withdrawn from validators
    // There is a threshold of the max amount of validators required for each validation, and this
    // should be set in the initializer.
    // for each validation, make a count.
    // resolve validation for even one failed validation.
    // at the end, verified validators call the `assign_validation`
    // for now, that required validation would come from the admin.
    //
    // `with_respect_of` matches with a poll id, if the poll isn't failed yet
    // but when this function us not for a poll, this value should be zero.
    // necessary checks must be made if that's the case, but one thing is certain...
    // before a validation takes place, there must be a need to validate it. Both parties must've
    // staked into the pool.
    fn validate(ref self: TContractState, target: Target, with_respect_of: u256);
    fn request_validation(ref self: TContractState, target: Target);
    fn assign_validation(ref self: TContractState, target: Target);
}

#[derive(Drop, Copy, Default, PartialEq, Serde)]
pub enum Target {
    #[default]
    Job: u256,
    User: ContractAddress,
    Credential: ContractAddress,
}
