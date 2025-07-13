#[starknet::component]
pub mod UserComponent {
    use starknet::ContractAddress;
    use starknet::storage::Map;
    use crate::interfaces::user::{IUser, User, UserNode, UserParams};

    #[storage]
    struct Storage {
        pub users: Map<ContractAddress, UserNode>,
    }

    #[embeddable_as(UserImpl)]
    pub impl UserComponent<
        TContractState, +HasComponent<TContractState>,
    > of IUser<ComponentState<TContractState>> {
        fn create_user(ref self: ComponentState<TContractState>, user_params: UserParams) {}
    }
}
