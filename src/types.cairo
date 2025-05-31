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
