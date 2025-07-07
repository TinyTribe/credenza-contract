#[starknet::component]
pub mod UserComponent {
    use starknet::storage::{Map, StoragePathEntry, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::user::{IUser, UserNode, UserParams};
    use crate::utils::base::Verification;

    #[storage]
    pub struct Storage {
        pub users: Map<ContractAddress, UserNode>,
    }

    #[embeddable_as(UserImpl)]
    pub impl User<
        TContractState, +HasComponent<TContractState>,
    > of IUser<ComponentState<TContractState>> {
        fn create_user(ref self: ComponentState<TContractState>, user_params: UserParams) {
            let caller = get_caller_address();
            let mut user_node = self.users.entry(caller);
            user_node.firstname.write(user_params.firstname);
            user_node.lastname.write(user_params.lastname);
            user_node.verification.write(Verification::Passed);
        }
    }
}
