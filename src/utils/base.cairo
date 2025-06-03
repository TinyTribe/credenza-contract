use core::num::traits::Zero;
use starknet::ContractAddress;

#[derive(Drop, Copy, PartialEq, Serde, Default, starknet::Store)]
pub enum Verification {
    #[default]
    Pending,
    Passed,
    Failed,
}

pub impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        Zero::zero()
    }
}

