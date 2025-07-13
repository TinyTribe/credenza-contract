use starknet::ContractAddress;

#[starknet::interface]
pub trait IIssuerRegistry<TContractState> {
    fn is_verified_issuer(self: @TContractState, issuer: ContractAddress) -> bool;
}

#[starknet::interface]
pub trait IMockIssuerRegistry<TContractState> {
    fn set_verified_issuer(ref self: TContractState, address: ContractAddress, is_verified: bool);
}

#[starknet::contract]
mod MockIssuerRegistry {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        verified_issuers: Map<ContractAddress, bool>,
    }

    #[abi(embed_v0)]
    impl MockIssuerRegistryImpl of super::IIssuerRegistry<ContractState> {
        fn is_verified_issuer(self: @ContractState, issuer: ContractAddress) -> bool {
            self.verified_issuers.read(issuer)
        }
    }

    #[abi(embed_v0)]
    impl MockFunctionsImpl of super::IMockIssuerRegistry<ContractState> {
        fn set_verified_issuer(
            ref self: ContractState, address: ContractAddress, is_verified: bool,
        ) {
            self.verified_issuers.write(address, is_verified);
        }
    }
}
