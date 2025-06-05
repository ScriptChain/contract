pub mod Roles {
    pub const Admin: u8 = 0;
    pub const EngagementManager: u8 = 1;
    pub const QuizManager: u8 = 2;
    pub const BookManager: u8 = 3;
    pub const RewardManager: u8 = 4;
}

pub mod AccessControlErrors {
    pub const NOT_AUTHORIZED: felt252 = 'Access: Not authorized';
    pub const INVALID_ADMIN: felt252 = 'Access: Invalid admin address';
    pub const CANNOT_RENOUNCE_ADMIN: felt252 = 'Access: Cannot renounce admin';
    pub const ZERO_ADDRESS: felt252 = 'Access: Zero address';
}

pub mod BookNFTErrors {
    pub const TOKEN_NOT_EXISTS: felt252 = 'Book: Token does not exist';
    pub const NOT_OWNER: felt252 = 'Book: Not token owner';
    pub const NOT_APPROVED: felt252 = 'Book: Not approved';
    pub const ALREADY_MINTED: felt252 = 'Book: Already minted';
    pub const INVALID_TOKEN_ID: felt252 = 'Book: Invalid token ID';
    pub const INVALID_ADDRESS: felt252 = 'Book: Invalid address';
    pub const TRANSFER_TO_SELF: felt252 = 'Book: Transfer to self';
    pub const ZERO_ADDRESS: felt252 = 'Book: Zero address';
    pub const INVALID_METADATA: felt252 = 'Book: Invalid metadata';
}

pub mod EngagementErrors {
    pub const INVALID_ENGAGEMENT_DATA: felt252 = 'Engagement: Invalid data';
    pub const REWARD_ALREADY_CLAIMED: felt252 = 'Engagement: Already claimed';
    pub const INSUFFICIENT_ENGAGEMENT: felt252 = 'Engagement: Insufficient score';
    pub const INVALID_SIGNATURE: felt252 = 'Engagement: Invalid signature';
    pub const EXPIRED_ENGAGEMENT: felt252 = 'Engagement: Data expired';
    pub const ZERO_REWARD_AMOUNT: felt252 = 'Engagement: Zero reward';
    pub const INVALID_VALIDATOR: felt252 = 'Engagement: Invalid validator';
    pub const COOLDOWN_ACTIVE: felt252 = 'Engagement: Cooldown active';
    pub const MAX_REWARDS_EXCEEDED: felt252 = 'Engagement: Max rewards hit';
    pub const INVALID_ENGAGEMENT_TYPE: felt252 = 'Engagement: Invalid type';
    pub const ZERO_ADDRESS: felt252 = 'Engagement: Zero address';
}

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct EngagementData {
    pub user: starknet::ContractAddress,
    pub engagement_type: u8, // 0: reading, 1: quiz, 2: interaction
    pub score: u64,
    pub duration: u64, // in seconds
    pub content_id: felt252,
    pub timestamp: u64,
    pub validator: starknet::ContractAddress,
}

// pub mod EngagemenType {
//     pub const
// }

#[derive(Drop, Serde, starknet::Store)]
pub struct RewardClaim {
    pub user: starknet::ContractAddress,
    pub engagement_hash: felt252,
    pub reward_amount: u256,
    pub claimed_at: u64,
    pub engagement_data: EngagementData,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct EngagementThresholds {
    pub reading_time_min: u64, // minimum reading time in seconds
    pub reading_score_min: u64, // minimum reading score
    pub quiz_score_min: u64, // minimum quiz score (percentage)
    pub interaction_score_min: u64 // minimum interaction score
}

#[derive(Drop, Serde, starknet::Store)]
pub struct RewardConfig {
    pub base_reading_reward: u256,
    pub base_quiz_reward: u256,
    pub base_interaction_reward: u256,
    pub bonus_multiplier: u256, // multiplier for exceptional performance
    pub max_daily_rewards: u256, // maximum rewards per user per day
    pub cooldown_period: u64 // cooldown between claims in seconds
}

pub const is_valid_signature: felt252 = selector!("is_valid_signature");
