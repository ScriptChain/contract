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
