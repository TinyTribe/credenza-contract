#[starknet::component]
pub mod UserComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::user::{IUser, UserNode, UserParams};
    use crate::utils::base::Verification;

    #[storage]
    pub struct Storage {
        pub users: Map<ContractAddress, UserNode>,
    }

    #[embeddable_as(UserImpl)]
    pub impl UserComponent<
        TContractState, +HasComponent<TContractState>,
    > of IUser<ComponentState<TContractState>> {
        fn create_user(ref self: ComponentState<TContractState>, user_params: UserParams) {
            let caller = get_caller_address();
            let user = self.users.entry(caller);
            
            // Set basic user information
            user.firstname.write(user_params.firstname);
            user.lastname.write(user_params.lastname);
            
            // Set verification status to Passed (for testing purposes)
            user.verification.write(Verification::Passed);
            
            // Initialize counters
            user.credentials_count.write(0);
            user.nft_count.write(0);
            
            // Process other addresses
            let mut i = 0;
            loop {
                if i >= user_params.other_addresses.len() {
                    break;
                }
                let addr = *user_params.other_addresses.at(i);
                user.other_addresses.entry(addr).write(true);
                i += 1;
            };
            
            // Process NFTs
            let mut j = 0;
            loop {
                if j >= user_params.nfts.len() {
                    break;
                }
                let nft_addr = *user_params.nfts.at(j);
                user.nfts.entry(nft_addr).write(1); // Default NFT count of 1
                j += 1;
            };
        }
    }
}

