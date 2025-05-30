use starknet::ContractAddress;

#[starknet::interface]
pub trait IAccessControl<TState> {
    fn has_role(self: @TState, role: u8, account: ContractAddress) -> bool;
    fn grant_role(ref self: TState, role: u8, account: ContractAddress);
    fn revoke_role(ref self: TState, role: u8, account: ContractAddress);
    fn renounce_role(ref self: TState, role: u8);
    fn set_role_admin(ref self: TState, role: u8, admin_role: u8);
    fn get_role_admin(self: @TState, role: u8) -> u8;
    fn get_admin(self: @TState) -> ContractAddress;
    fn transfer_admin(ref self: TState, new_admin: ContractAddress);
}
