#[starknet::component]
pub mod AccessControlComponent {
    use starknet::{
        ContractAddress, get_caller_address,
        storage::{
            StoragePointerWriteAccess, StoragePointerReadAccess, Map, StorageMapReadAccess,
            StorageMapWriteAccess,
        },
    };
    use scriptchain::{
        interfaces::access_control::IAccessControl, types::{Roles, AccessControlErrors as Errors},
    };

    #[storage]
    pub struct Storage {
        roles: Map<(ContractAddress, u8), bool>,
        role_admin: Map<u8, u8>,
        admin: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
        RoleAdminChanged: RoleAdminChanged,
        AdminTransferred: AdminTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleGranted {
        #[key]
        role: u8,
        #[key]
        account: ContractAddress,
        #[key]
        sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleRevoked {
        #[key]
        role: u8,
        #[key]
        account: ContractAddress,
        #[key]
        sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleAdminChanged {
        #[key]
        role: u8,
        previous_admin_role: u8,
        new_admin_role: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AdminTransferred {
        #[key]
        previous_admin: ContractAddress,
        #[key]
        new_admin: ContractAddress,
    }

    #[embeddable_as(AccessControlImpl)]
    pub impl AccessControl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IAccessControl<ComponentState<TContractState>> {
        fn has_role(
            self: @ComponentState<TContractState>, role: u8, account: ContractAddress,
        ) -> bool {
            self.roles.read((account, role))
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: u8, account: ContractAddress,
        ) {
            let caller = get_caller_address();

            let admin_role = self.role_admin.read(role);
            assert(self._has_role(admin_role, caller), Errors::NOT_AUTHORIZED);

            self._grant_role(role, account);
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: u8, account: ContractAddress,
        ) {
            let caller = get_caller_address();

            let admin_role = self.role_admin.read(role);
            assert(self._has_role(admin_role, caller), Errors::NOT_AUTHORIZED);

            self._revoke_role(role, account);
        }

        fn renounce_role(ref self: ComponentState<TContractState>, role: u8) {
            let caller = get_caller_address();

            // Prevent renouncing admin role if caller is the main admin
            if role == Roles::Admin {
                assert(caller != self.admin.read(), Errors::CANNOT_RENOUNCE_ADMIN);
            }

            // Revoke the role for the caller
            self._revoke_role(role, caller);
        }

        fn set_role_admin(ref self: ComponentState<TContractState>, role: u8, admin_role: u8) {
            let caller = get_caller_address();

            // Only the main admin can set role admins
            assert(caller == self.admin.read(), Errors::NOT_AUTHORIZED);

            self._set_role_admin(role, admin_role);
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: u8) -> u8 {
            self.role_admin.read(role)
        }

        fn get_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.admin.read()
        }

        fn transfer_admin(ref self: ComponentState<TContractState>, new_admin: ContractAddress) {
            let caller = get_caller_address();
            let current_admin = self.admin.read();

            // Only current admin can transfer admin rights
            assert(caller == current_admin, Errors::NOT_AUTHORIZED);

            // Transfer admin role
            self._revoke_role(Roles::Admin, current_admin);
            self._grant_role(Roles::Admin, new_admin);

            // Update admin address
            self.admin.write(new_admin);

            // Emit event
            self.emit(AdminTransferred { previous_admin: current_admin, new_admin: new_admin });
        }
    }

    #[generate_trait]
    pub impl InternalFunctions<
        TContractState, +HasComponent<TContractState>,
    > of InternalFunctionsTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin_address: ContractAddress) {
            self.admin.write(admin_address);

            self._grant_role(Roles::Admin, admin_address);

            // Set up role hierarchy - Admin is the admin of all roles
            self._set_role_admin(Roles::EngagementManager, Roles::Admin);
            self._set_role_admin(Roles::QuizManager, Roles::Admin);
            self._set_role_admin(Roles::BookManager, Roles::Admin);
            self._set_role_admin(Roles::RewardManager, Roles::Admin);
            self._set_role_admin(Roles::Admin, Roles::Admin);
        }

        fn _has_role(
            self: @ComponentState<TContractState>, role: u8, account: ContractAddress,
        ) -> bool {
            self.roles.read((account, role))
        }

        fn _grant_role(
            ref self: ComponentState<TContractState>, role: u8, account: ContractAddress,
        ) {
            let had_role = self._has_role(role, account);

            if !had_role {
                let caller = get_caller_address();
                self.roles.write((account, role), true);

                self.emit(RoleGranted { role: role, account: account, sender: caller });
            }
        }

        fn _revoke_role(
            ref self: ComponentState<TContractState>, role: u8, account: ContractAddress,
        ) {
            let had_role = self._has_role(role, account);

            if had_role {
                let caller = get_caller_address();
                self.roles.write((account, role), false);

                self.emit(RoleRevoked { role: role, account: account, sender: caller });
            }
        }

        fn _set_role_admin(ref self: ComponentState<TContractState>, role: u8, admin_role: u8) {
            let previous_admin_role = self.role_admin.read(role);
            self.role_admin.write(role, admin_role);

            self
                .emit(
                    RoleAdminChanged {
                        role: role,
                        previous_admin_role: previous_admin_role,
                        new_admin_role: admin_role,
                    },
                );
        }

        fn only_role(self: @ComponentState<TContractState>, role: u8) {
            let caller = get_caller_address();
            assert(self._has_role(role, caller), Errors::NOT_AUTHORIZED);
        }

        fn only_admin(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), Errors::NOT_AUTHORIZED);
        }

        fn setup_role(
            ref self: ComponentState<TContractState>,
            role: u8,
            admin_role: u8,
            account: ContractAddress,
        ) {
            self._set_role_admin(role.clone(), admin_role);
            self._grant_role(role.clone(), account);
        }
    }
}
