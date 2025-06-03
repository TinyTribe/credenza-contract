#[starknet::contract]
pub mod Core {
    use starknet::ContractAddress;
    use crate::components::credenza::CredenzaComponent;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}
}
