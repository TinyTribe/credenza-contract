#[starknet::component]
pub mod UserComponent {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry};
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::user::{IUser, UserNode, UserParams};

    #[storage]
    struct Storage {
        pub users: Map<ContractAddress, UserNode>,
    }

    #[embeddable_as(UserImpl)]
    pub impl User<
        TContractState, +HasComponent<TContractState>,
    > of IUser<ComponentState<TContractState>> {
        fn create_user(ref self: ComponentState<TContractState>, user_params: UserParams) {}
    }
}
