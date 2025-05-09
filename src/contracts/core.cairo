#[starknet::contract]
pub mod Core {
    use starknet::ContractAddress;
    use crate::components::job::JobComponent;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}
}
