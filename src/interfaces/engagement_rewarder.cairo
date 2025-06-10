use starknet::{ContractAddress, eth_address::EthAddress, secp256_trait::Signature};
use scriptchain::types::{EngagementData, RewardClaim, EngagementThresholds, RewardConfig};

#[starknet::interface]
pub trait IEngagementRewarder<TContractState> {
    // Core reward functions
    fn claim_reward(
        ref self: TContractState, engagement_data: EngagementData, signature: Signature,
    ) -> u256;
    fn batch_claim_rewards(
        ref self: TContractState,
        engagement_data_array: Array<EngagementData>,
        signatures: Array<Signature>,
    ) -> Array<u256>;

    // View functions
    fn calculate_reward(self: @TContractState, engagement_data: EngagementData) -> u256;
    fn is_eligible_for_reward(self: @TContractState, engagement_data: EngagementData) -> bool;
    fn get_user_daily_rewards(self: @TContractState, user: ContractAddress) -> u256;
    fn get_reward_claim(self: @TContractState, engagement_hash: felt252) -> RewardClaim;
    fn is_reward_claimed(self: @TContractState, engagement_hash: felt252) -> bool;
    fn get_last_claim_time(self: @TContractState, user: ContractAddress) -> u64;

    // Configuration functions (admin only)
    fn set_reward_config(ref self: TContractState, config: RewardConfig);
    fn set_engagement_thresholds(ref self: TContractState, thresholds: EngagementThresholds);
    fn set_reward_token(ref self: TContractState, token_address: ContractAddress);
    fn add_validator(ref self: TContractState, validator: ContractAddress);
    fn remove_validator(ref self: TContractState, validator: ContractAddress);
    fn pause_rewards(ref self: TContractState);
    fn unpause_rewards(ref self: TContractState);
    fn set_eth_signer_address(ref self: TContractState, eth_signer_address: EthAddress);

    // View configuration functions
    fn get_reward_config(self: @TContractState) -> RewardConfig;
    fn get_engagement_thresholds(self: @TContractState) -> EngagementThresholds;
    fn get_reward_token(self: @TContractState) -> ContractAddress;
    fn is_validator(self: @TContractState, validator: ContractAddress) -> bool;
    fn is_paused(self: @TContractState) -> bool;
    fn get_eth_signer_address(self: @TContractState) -> EthAddress;

    // Emergency functions (admin only)
    fn emergency_withdraw(ref self: TContractState, amount: u256);
    fn reset_user_daily_rewards(ref self: TContractState, user: ContractAddress);
}
