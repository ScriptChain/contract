//engagement rewarder

#[starknet::contract]
pub mod EngagementRewarder {
    use starknet::{
        eth_address::EthAddress, eth_signature::verify_eth_signature, ContractAddress,
        get_caller_address, get_block_timestamp,
        storage::{
            StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry,
            StorageMapReadAccess, StorageMapWriteAccess,
        },
        secp256_trait::Signature,
    };
    use core::{
        num::traits::Zero, array::ArrayTrait, hash::HashStateTrait, poseidon::{PoseidonTrait},
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use scriptchain::types::{
        EngagementData, RewardClaim, EngagementThresholds, RewardConfig, EngagementErrors as Errors,
    };
    use scriptchain::interfaces::engagement_rewarder::IEngagementRewarder;

    // Components
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // Core contract state
        reward_token: ContractAddress,
        reward_config: RewardConfig,
        engagement_thresholds: EngagementThresholds,
        paused: bool,
        // Tracking user rewards and claims
        user_daily_rewards: Map<(ContractAddress, u64), u256>, // (user, day) -> total_rewards
        user_last_claim: Map<ContractAddress, u64>, // user -> timestamp
        reward_claims: Map<felt252, RewardClaim>, // engagement_hash -> claim
        claimed_engagements: Map<felt252, bool>, // engagement_hash -> claimed
        // Validators and access control
        validators: Map<ContractAddress, bool>,
        // Nonce tracking for replay protection
        user_nonces: Map<ContractAddress, u64>,
        eth_signer_address: EthAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        RewardClaimed: RewardClaimed,
        BatchRewardsClaimed: BatchRewardsClaimed,
        RewardConfigUpdated: RewardConfigUpdated,
        ThresholdsUpdated: ThresholdsUpdated,
        ValidatorAdded: ValidatorAdded,
        ValidatorRemoved: ValidatorRemoved,
        RewardsPaused: RewardsPaused,
        RewardsUnpaused: RewardsUnpaused,
        EmergencyWithdrawal: EmergencyWithdrawal,
        UserDailyRewardsReset: UserDailyRewardsReset,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardClaimed {
        pub user: ContractAddress,
        pub engagement_hash: felt252,
        pub reward_amount: u256,
        pub engagement_type: u8,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BatchRewardsClaimed {
        pub user: ContractAddress,
        pub total_rewards: u256,
        pub claims_count: u32,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardConfigUpdated {
        pub by: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ThresholdsUpdated {
        pub by: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ValidatorAdded {
        pub validator: ContractAddress,
        pub by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ValidatorRemoved {
        pub validator: ContractAddress,
        pub by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardsPaused {
        pub by: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardsUnpaused {
        pub by: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyWithdrawal {
        pub amount: u256,
        pub by: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UserDailyRewardsReset {
        pub user: ContractAddress,
        pub by: ContractAddress,
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        reward_token: ContractAddress,
        initial_admin: ContractAddress,
        eth_signer_address: EthAddress,
    ) {
        self.ownable.initializer(initial_admin);
        self.reward_token.write(reward_token);
        self.paused.write(false);

        // Set default configuration
        let default_config = RewardConfig {
            base_reading_reward: 100_u256, // 100 tokens for reading
            base_quiz_reward: 200_u256, // 200 tokens for quiz
            base_interaction_reward: 50_u256, // 50 tokens for interaction
            bonus_multiplier: 150_u256, // 1.5x multiplier for exceptional performance
            max_daily_rewards: 10000_u256, // 10,000 tokens max per day
            cooldown_period: 3600_u64 // 1 hour cooldown
        };
        self.reward_config.write(default_config);
        self.eth_signer_address.write(eth_signer_address);

        // Set default thresholds
        let default_thresholds = EngagementThresholds {
            reading_time_min: 300_u64, // 5 minutes minimum reading
            reading_score_min: 70_u64, // 70% minimum reading score
            quiz_score_min: 80_u64, // 80% minimum quiz score
            interaction_score_min: 60_u64 // 60% minimum interaction score
        };
        self.engagement_thresholds.write(default_thresholds);

        // Set initial admin as validator
        self.validators.entry(initial_admin).write(true);
    }

    #[abi(embed_v0)]
    impl EngagementRewarderImpl of IEngagementRewarder<ContractState> {
        fn claim_reward(
            ref self: ContractState, engagement_data: EngagementData, signature: Signature,
        ) -> u256 {
            self._assert_not_paused();
            self._validate_engagement_data(@engagement_data);

            let caller = get_caller_address();
            assert(engagement_data.user == caller, Errors::INVALID_ENGAGEMENT_DATA);

            // Check cooldown
            self._check_cooldown(caller);

            // Generate engagement hash for uniqueness
            let engagement_hash = self._generate_engagement_hash(engagement_data.clone());

            // Check if already claimed
            assert(!self.claimed_engagements.read(engagement_hash), Errors::REWARD_ALREADY_CLAIMED);

            // Verify signature
            verify_eth_signature(engagement_hash.into(), signature, self.eth_signer_address.read());

            // Check eligibility
            assert(
                self.is_eligible_for_reward(engagement_data.clone()),
                Errors::INSUFFICIENT_ENGAGEMENT,
            );

            // Calculate reward
            let reward_amount = self.calculate_reward(engagement_data.clone());
            assert(reward_amount > 0, Errors::ZERO_REWARD_AMOUNT);

            // Check daily limits
            self._check_daily_limits(caller, reward_amount);

            // Record the claim
            let current_time = get_block_timestamp();
            let claim = RewardClaim {
                user: caller,
                engagement_hash,
                reward_amount,
                claimed_at: current_time,
                engagement_data: engagement_data.clone(),
            };

            self.reward_claims.entry(engagement_hash).write(claim);
            self.claimed_engagements.entry(engagement_hash).write(true);
            self.user_last_claim.entry(caller).write(current_time);

            // Update daily rewards
            let today = current_time / 86400; // seconds in a day
            let current_daily = self.user_daily_rewards.entry((caller, today)).read();
            self.user_daily_rewards.entry((caller, today)).write(current_daily + reward_amount);

            // Increment user nonce
            let current_nonce = self.user_nonces.entry(caller).read();
            self.user_nonces.entry(caller).write(current_nonce + 1);

            // Transfer reward tokens
            let token = IERC20Dispatcher { contract_address: self.reward_token.read() };
            token.transfer(caller, reward_amount);

            // Emit event
            self
                .emit(
                    RewardClaimed {
                        user: caller,
                        engagement_hash,
                        reward_amount,
                        engagement_type: engagement_data.engagement_type,
                        timestamp: current_time,
                    },
                );

            reward_amount
        }

        fn batch_claim_rewards(
            ref self: ContractState,
            engagement_data_array: Array<EngagementData>,
            signatures: Array<Signature>,
        ) -> Array<u256> {
            self._assert_not_paused();

            let caller = get_caller_address();
            let data_len = engagement_data_array.len();
            assert(data_len == signatures.len(), Errors::INVALID_ENGAGEMENT_DATA);
            assert(
                data_len > 0 && data_len <= 10, Errors::INVALID_ENGAGEMENT_DATA,
            ); // Max 10 claims per batch

            let mut rewards = ArrayTrait::new();
            let mut total_rewards = 0_u256;
            let current_time = get_block_timestamp();

            let mut i = 0;
            while i < data_len {
                let engagement_data = engagement_data_array.at(i);
                let signature = signatures[i];

                // Validate each engagement data
                self._validate_engagement_data(engagement_data);
                assert(*engagement_data.user == caller, Errors::INVALID_ENGAGEMENT_DATA);

                let engagement_hash = self._generate_engagement_hash(engagement_data.clone());

                // Skip if already claimed
                if self.claimed_engagements.entry(engagement_hash).read() {
                    rewards.append(0);
                    i += 1;
                    continue;
                }

                // Verify signature and eligibility
                verify_eth_signature(
                    engagement_hash.into(), *signature, self.eth_signer_address.read(),
                );

                if !self.is_eligible_for_reward(engagement_data.clone()) {
                    rewards.append(0);
                    i += 1;
                    continue;
                }

                let reward_amount = self.calculate_reward(engagement_data.clone());

                if reward_amount > 0 {
                    // Record the claim
                    let claim = RewardClaim {
                        user: caller,
                        engagement_hash,
                        reward_amount,
                        claimed_at: current_time,
                        engagement_data: engagement_data.clone(),
                    };

                    self.reward_claims.entry(engagement_hash).write(claim);
                    self.claimed_engagements.entry(engagement_hash).write(true);
                    total_rewards += reward_amount;
                }

                rewards.append(reward_amount);
                i += 1;
            };

            if total_rewards > 0 {
                // Check daily limits for total
                self._check_daily_limits(caller, total_rewards);

                // Update state
                self.user_last_claim.entry(caller).write(current_time);
                let today = current_time / 86400;
                let current_daily = self.user_daily_rewards.entry((caller, today)).read();
                self.user_daily_rewards.entry((caller, today)).write(current_daily + total_rewards);

                // Increment user nonce
                let current_nonce = self.user_nonces.entry(caller).read();
                self.user_nonces.entry(caller).write(current_nonce + 1);

                // Transfer total reward tokens
                let token = IERC20Dispatcher { contract_address: self.reward_token.read() };
                token.transfer(caller, total_rewards);

                // Emit batch event
                self
                    .emit(
                        BatchRewardsClaimed {
                            user: caller,
                            total_rewards,
                            claims_count: data_len,
                            timestamp: current_time,
                        },
                    );
            }

            rewards
        }

        fn calculate_reward(self: @ContractState, engagement_data: EngagementData) -> u256 {
            let config = self.reward_config.read();

            let base_reward = match engagement_data.engagement_type {
                0 => config.base_reading_reward, // reading
                1 => config.base_quiz_reward, // quiz
                2 => config.base_interaction_reward, // interaction
                _ => 0_u256,
            };

            if base_reward == 0 {
                return 0;
            }

            // Apply performance-based multiplier
            let score_multiplier = self._calculate_score_multiplier(@engagement_data);
            let duration_multiplier = self._calculate_duration_multiplier(@engagement_data);

            // Calculate final reward
            let reward = base_reward
                * score_multiplier
                * duration_multiplier
                / 10000; // Divide by 10000 for percentage

            // Apply bonus for exceptional performance
            let thresholds = self.engagement_thresholds.read();
            let exceptional_threshold = match engagement_data.engagement_type {
                0 => thresholds.reading_score_min + 20, // 20% above minimum
                1 => thresholds.quiz_score_min + 15, // 15% above minimum
                2 => thresholds.interaction_score_min + 25, // 25% above minimum
                _ => 0_u64,
            };

            if engagement_data.score >= exceptional_threshold {
                reward * self.reward_config.read().bonus_multiplier / 100 // Apply bonus multiplier
            } else {
                reward
            }
        }

        fn set_eth_signer_address(ref self: ContractState, eth_signer_address: EthAddress) {
            self.ownable.assert_only_owner();
            self.eth_signer_address.write(eth_signer_address);
        }

        fn get_eth_signer_address(self: @ContractState) -> EthAddress {
            self.eth_signer_address.read()
        }

        fn is_eligible_for_reward(self: @ContractState, engagement_data: EngagementData) -> bool {
            let thresholds = self.engagement_thresholds.read();

            match engagement_data.engagement_type {
                0 => { // reading
                    engagement_data.duration >= thresholds.reading_time_min
                        && engagement_data.score >= thresholds.reading_score_min
                },
                1 => { // quiz
                engagement_data.score >= thresholds.quiz_score_min },
                2 => { // interaction
                engagement_data.score >= thresholds.interaction_score_min },
                _ => false,
            }
        }

        fn get_user_daily_rewards(self: @ContractState, user: ContractAddress) -> u256 {
            let today = get_block_timestamp() / 86400;
            self.user_daily_rewards.entry((user, today)).read()
        }

        fn get_reward_claim(self: @ContractState, engagement_hash: felt252) -> RewardClaim {
            self.reward_claims.entry(engagement_hash).read()
        }

        fn is_reward_claimed(self: @ContractState, engagement_hash: felt252) -> bool {
            self.claimed_engagements.entry(engagement_hash).read()
        }

        fn get_last_claim_time(self: @ContractState, user: ContractAddress) -> u64 {
            self.user_last_claim.entry(user).read()
        }

        // Configuration functions (admin only)
        fn set_reward_config(ref self: ContractState, config: RewardConfig) {
            self.ownable.assert_only_owner();
            self.reward_config.write(config);

            self
                .emit(
                    RewardConfigUpdated {
                        by: get_caller_address(), timestamp: get_block_timestamp(),
                    },
                );
        }

        fn set_engagement_thresholds(ref self: ContractState, thresholds: EngagementThresholds) {
            self.ownable.assert_only_owner();
            self.engagement_thresholds.write(thresholds);

            self
                .emit(
                    ThresholdsUpdated {
                        by: get_caller_address(), timestamp: get_block_timestamp(),
                    },
                );
        }

        fn set_reward_token(ref self: ContractState, token_address: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(!token_address.is_zero(), Errors::ZERO_ADDRESS);
            self.reward_token.write(token_address);
        }

        fn add_validator(ref self: ContractState, validator: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(!validator.is_zero(), Errors::ZERO_ADDRESS);
            self.validators.entry(validator).write(true);

            self.emit(ValidatorAdded { validator, by: get_caller_address() });
        }

        fn remove_validator(ref self: ContractState, validator: ContractAddress) {
            self.ownable.assert_only_owner();
            self.validators.entry(validator).write(false);

            self.emit(ValidatorRemoved { validator, by: get_caller_address() });
        }

        fn pause_rewards(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.paused.write(true);

            self.emit(RewardsPaused { by: get_caller_address(), timestamp: get_block_timestamp() });
        }

        fn unpause_rewards(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.paused.write(false);

            self
                .emit(
                    RewardsUnpaused { by: get_caller_address(), timestamp: get_block_timestamp() },
                );
        }

        // View configuration functions
        fn get_reward_config(self: @ContractState) -> RewardConfig {
            self.reward_config.read()
        }

        fn get_engagement_thresholds(self: @ContractState) -> EngagementThresholds {
            self.engagement_thresholds.read()
        }

        fn get_reward_token(self: @ContractState) -> ContractAddress {
            self.reward_token.read()
        }

        fn is_validator(self: @ContractState, validator: ContractAddress) -> bool {
            self.validators.entry(validator).read()
        }

        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        // Emergency functions (admin only)
        fn emergency_withdraw(ref self: ContractState, amount: u256) {
            self.ownable.assert_only_owner();
            let token = IERC20Dispatcher { contract_address: self.reward_token.read() };
            let caller = get_caller_address();
            token.transfer(caller, amount);

            self.emit(EmergencyWithdrawal { amount, by: caller, timestamp: get_block_timestamp() });
        }

        fn reset_user_daily_rewards(ref self: ContractState, user: ContractAddress) {
            self.ownable.assert_only_owner();
            let today = get_block_timestamp() / 86400;
            self.user_daily_rewards.entry((user, today)).write(0);

            self
                .emit(
                    UserDailyRewardsReset {
                        user, by: get_caller_address(), timestamp: get_block_timestamp(),
                    },
                );
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), 'Contract is paused');
        }

        fn _validate_engagement_data(self: @ContractState, engagement_data: @EngagementData) {
            assert(!engagement_data.user.is_zero(), Errors::INVALID_ENGAGEMENT_DATA);
            assert(*engagement_data.engagement_type <= 2, Errors::INVALID_ENGAGEMENT_TYPE);
            assert(*engagement_data.score <= 100, Errors::INVALID_ENGAGEMENT_DATA);
            assert(*engagement_data.duration > 0, Errors::INVALID_ENGAGEMENT_DATA);
            assert(*engagement_data.content_id != 0, Errors::INVALID_ENGAGEMENT_DATA);

            // Check if engagement data is not too old (24 hours)
            let current_time = get_block_timestamp();
            assert(current_time - *engagement_data.timestamp <= 86400, Errors::EXPIRED_ENGAGEMENT);
        }

        fn _check_cooldown(self: @ContractState, user: ContractAddress) {
            let config = self.reward_config.read();
            let last_claim = self.user_last_claim.entry(user).read();
            let current_time = get_block_timestamp();

            if last_claim > 0 {
                assert(
                    current_time - last_claim >= config.cooldown_period, Errors::COOLDOWN_ACTIVE,
                );
            }
        }

        fn _check_daily_limits(self: @ContractState, user: ContractAddress, reward_amount: u256) {
            let config = self.reward_config.read();
            let today = get_block_timestamp() / 86400;
            let current_daily = self.user_daily_rewards.entry((user, today)).read();

            assert(
                current_daily + reward_amount <= config.max_daily_rewards,
                Errors::MAX_REWARDS_EXCEEDED,
            );
        }

        fn _generate_engagement_hash(
            self: @ContractState, engagement_data: EngagementData,
        ) -> felt252 {
            let mut hash_data = PoseidonTrait::new()
                .update(engagement_data.user.into())
                .update(engagement_data.engagement_type.into())
                .update(engagement_data.score.into())
                .update(engagement_data.duration.into())
                .update(engagement_data.content_id.into())
                .update(engagement_data.timestamp.into())
                .update(engagement_data.validator.into())
                .finalize();

            hash_data
        }

        fn _calculate_score_multiplier(
            self: @ContractState, engagement_data: @EngagementData,
        ) -> u256 {
            // Base multiplier is 100 (represents 100%)
            let base = 100_u256;

            // Add bonus based on score
            if *engagement_data.score >= 90 {
                base + 30 // 30% bonus for 90%+ score
            } else if *engagement_data.score >= 80 {
                base + 20 // 20% bonus for 80%+ score
            } else if *engagement_data.score >= 70 {
                base + 10 // 10% bonus for 70%+ score
            } else {
                base
            }
        }

        fn _calculate_duration_multiplier(
            self: @ContractState, engagement_data: @EngagementData,
        ) -> u256 {
            // Only apply duration multiplier for reading type
            if *engagement_data.engagement_type != 0 {
                return 100_u256; // 100% for non-reading activities
            }

            let duration = *engagement_data.duration;

            // Base multiplier is 100 (represents 100%)
            if duration >= 1800 { // 30+ minutes
                120_u256 // 20% bonus
            } else if duration >= 900 { // 15+ minutes
                110_u256 // 10% bonus
            } else if duration >= 600 { // 10+ minutes
                105_u256 // 5% bonus
            } else {
                100_u256 // No bonus
            }
        }
    }
}
