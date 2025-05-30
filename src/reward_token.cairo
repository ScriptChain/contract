#[starknet::contract]
pub mod RewardToken {
    use starknet::{ClassHash, get_caller_address, ContractAddress};
    use core::starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry,
    };
    use openzeppelin::{
        access::ownable::OwnableComponent, token::erc20::{ERC20Component, ERC20HooksEmptyImpl},
        introspection::src5::SRC5Component, upgrades::UpgradeableComponent,
    };
    use scriptchain::interfaces::reward_token::IRewardToken;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Role-based access control
        minters: Map<ContractAddress, bool>,
        burners: Map<ContractAddress, bool>,
        // Pause functionality
        paused: bool,
        // Account freezing
        frozen_accounts: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        // Custom events
        MinterAdded: MinterAdded,
        MinterRemoved: MinterRemoved,
        BurnerAdded: BurnerAdded,
        BurnerRemoved: BurnerRemoved,
        TokensMinted: TokensMinted,
        TokensBurned: TokensBurned,
        ContractPaused: ContractPaused,
        ContractUnpaused: ContractUnpaused,
        AccountFrozen: AccountFrozen,
        AccountUnfrozen: AccountUnfrozen,
        EmergencyBurn: EmergencyBurn,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterAdded {
        pub minter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterRemoved {
        pub minter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BurnerAdded {
        pub burner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BurnerRemoved {
        pub burner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensMinted {
        pub to: ContractAddress,
        pub amount: u256,
        pub minter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensBurned {
        pub from: ContractAddress,
        pub amount: u256,
        pub burner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractPaused {
        pub by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractUnpaused {
        pub by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AccountFrozen {
        pub account: ContractAddress,
        pub by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AccountUnfrozen {
        pub account: ContractAddress,
        pub by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyBurn {
        pub from: ContractAddress,
        pub amount: u256,
        pub by: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, total_supply: u256,
    ) {
        let caller = get_caller_address();

        // Initialize components
        self.ownable.initializer(caller);
        self.erc20.initializer(name, symbol);
        self
            .src5
            .register_interface(
                interface_id: 0x36372b07000000000000000000000000,
            ); // IERC20 interface id

        // Initialize contract state
        self.paused.write(false);

        // Set deployer as initial minter and burner
        self.minters.entry(caller).write(true);
        self.burners.entry(caller).write(true);

        // Mint total supply to the deployer
        self.erc20.mint(caller, total_supply);
    }

    #[abi(embed_v0)]
    impl RewardTokenImpl of IRewardToken<ContractState> {
        /// @notice upgrades the token contract
        /// @param new_class_hash classhash to upgrade to
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self._assert_not_paused();

            // Replace the class hash upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }

        /// @notice Mints tokens to a specified address
        /// @param to The address to mint tokens to
        /// @param amount The amount of tokens to mint
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self._assert_only_minter();
            self._assert_not_paused();
            self._assert_not_frozen(to);

            assert!(amount > 0, "Amount must be greater than 0");

            let caller = get_caller_address();
            self.erc20.mint(to, amount);

            self.emit(TokensMinted { to, amount, minter: caller });
        }

        /// @notice Burns tokens from a specified address (requires approval or owner)
        /// @param from The address to burn tokens from
        /// @param amount The amount of tokens to burn
        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self._assert_only_burner();
            self._assert_not_paused();
            self._assert_not_frozen(from);

            assert!(amount > 0, "Amount must be greater than 0");

            let caller = get_caller_address();

            // If caller is not the from address, check allowance
            if caller != from {
                let current_allowance = self.erc20.allowance(from, caller);
                assert!(current_allowance >= amount, "Insufficient allowance");
                self.erc20.approve(caller, current_allowance - amount);
            }

            self.erc20.burn(from, amount);

            self.emit(TokensBurned { from, amount, burner: caller });
        }

        /// @notice Burns tokens from the caller's account
        /// @param amount The amount of tokens to burn
        fn burn_from_caller(ref self: ContractState, amount: u256) {
            self._assert_not_paused();
            let caller = get_caller_address();
            self._assert_not_frozen(caller);

            assert!(amount > 0, "Amount must be greater than 0");

            self.erc20.burn(caller, amount);

            self.emit(TokensBurned { from: caller, amount, burner: caller });
        }

        /// @notice Sets minter role for an address
        /// @param minter The address to set minter role for
        /// @param is_minter Whether to grant or revoke minter role
        fn set_minter(ref self: ContractState, minter: ContractAddress, is_minter: bool) {
            self.ownable.assert_only_owner();

            self.minters.entry(minter).write(is_minter);

            if is_minter {
                self.emit(MinterAdded { minter });
            } else {
                self.emit(MinterRemoved { minter });
            }
        }

        /// @notice Sets burner role for an address
        /// @param burner The address to set burner role for
        /// @param is_burner Whether to grant or revoke burner role
        fn set_burner(ref self: ContractState, burner: ContractAddress, is_burner: bool) {
            self.ownable.assert_only_owner();

            self.burners.entry(burner).write(is_burner);

            if is_burner {
                self.emit(BurnerAdded { burner });
            } else {
                self.emit(BurnerRemoved { burner });
            }
        }

        /// @notice Checks if an address has minter role
        /// @param account The address to check
        /// @return Whether the address has minter role
        fn is_minter(self: @ContractState, account: ContractAddress) -> bool {
            self.minters.entry(account).read()
        }

        /// @notice Checks if an address has burner role
        /// @param account The address to check
        /// @return Whether the address has burner role
        fn is_burner(self: @ContractState, account: ContractAddress) -> bool {
            self.burners.entry(account).read()
        }

        /// @notice Pauses the contract (only owner)
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            assert!(!self.paused.read(), "Contract is already paused");

            self.paused.write(true);

            let caller = get_caller_address();
            self.emit(ContractPaused { by: caller });
        }

        /// @notice Unpauses the contract (only owner)
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            assert!(self.paused.read(), "Contract is not paused");

            self.paused.write(false);

            let caller = get_caller_address();
            self.emit(ContractUnpaused { by: caller });
        }

        /// @notice Checks if the contract is paused
        /// @return Whether the contract is paused
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        /// @notice Emergency burn function (only owner, works even when paused)
        /// @param from The address to burn tokens from
        /// @param amount The amount of tokens to burn
        fn emergency_burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();

            assert!(amount > 0, "Amount must be greater than 0");

            let caller = get_caller_address();
            self.erc20.burn(from, amount);

            self.emit(EmergencyBurn { from, amount, by: caller });
        }

        /// @notice Freezes an account (only owner)
        /// @param account The account to freeze
        fn freeze_account(ref self: ContractState, account: ContractAddress) {
            self.ownable.assert_only_owner();
            assert!(!self.frozen_accounts.entry(account).read(), "Account is already frozen");

            self.frozen_accounts.entry(account).write(true);

            let caller = get_caller_address();
            self.emit(AccountFrozen { account, by: caller });
        }

        /// @notice Unfreezes an account (only owner)
        /// @param account The account to unfreeze
        fn unfreeze_account(ref self: ContractState, account: ContractAddress) {
            self.ownable.assert_only_owner();
            assert!(self.frozen_accounts.entry(account).read(), "Account is not frozen");

            self.frozen_accounts.entry(account).write(false);

            let caller = get_caller_address();
            self.emit(AccountUnfrozen { account, by: caller });
        }

        /// @notice Checks if an account is frozen
        /// @param account The account to check
        /// @return Whether the account is frozen
        fn is_frozen(self: @ContractState, account: ContractAddress) -> bool {
            self.frozen_accounts.entry(account).read()
        }
    }

    /// Internal helper functions
    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        /// @notice Asserts that the caller has minter role
        fn _assert_only_minter(self: @ContractState) {
            let caller = get_caller_address();
            assert!(
                self.minters.entry(caller).read() || caller == self.ownable.owner(),
                "RewardToken: Caller is not a minter",
            );
        }

        /// @notice Asserts that the caller has burner role
        fn _assert_only_burner(self: @ContractState) {
            let caller = get_caller_address();
            assert!(
                self.burners.entry(caller).read() || caller == self.ownable.owner(),
                "RewardToken: Caller is not a burner",
            );
        }

        /// @notice Asserts that the contract is not paused
        fn _assert_not_paused(self: @ContractState) {
            assert!(!self.paused.read(), "RewardToken: Contract is paused");
        }

        /// @notice Asserts that an account is not frozen
        fn _assert_not_frozen(self: @ContractState, account: ContractAddress) {
            assert!(!self.frozen_accounts.entry(account).read(), "RewardToken: Account is frozen");
        }
    }
}
