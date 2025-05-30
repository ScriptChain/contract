use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IRewardToken<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn burn_from_caller(ref self: TContractState, amount: u256);
    fn set_minter(ref self: TContractState, minter: ContractAddress, is_minter: bool);
    fn set_burner(ref self: TContractState, burner: ContractAddress, is_burner: bool);
    fn is_minter(self: @TContractState, account: ContractAddress) -> bool;
    fn is_burner(self: @TContractState, account: ContractAddress) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    fn emergency_burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn freeze_account(ref self: TContractState, account: ContractAddress);
    fn unfreeze_account(ref self: TContractState, account: ContractAddress);
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
}
