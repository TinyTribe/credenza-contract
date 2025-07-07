#[starknet::contract]
pub mod Core {
    use starknet::ContractAddress;
    use crate::components::credenza::CredenzaComponent;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        credenza: CredenzaComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}
}
