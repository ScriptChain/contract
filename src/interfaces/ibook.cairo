use starknet::{ClassHash, ContractAddress};

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct BookMetadata {
    pub title: ByteArray,
    pub author: ByteArray,
    pub genre: ByteArray,
    pub isbn: ByteArray,
    pub publication_year: u32,
    pub page_count: u32,
    pub language: ByteArray,
    pub description: ByteArray,
    pub cover_image_uri: ByteArray,
}

#[starknet::interface]
pub trait IBookNFT<TState> {
    fn get_base_uri(self: @TState) -> ByteArray;

    // Book-specific Functions
    fn mint_book(
        ref self: TState, to: ContractAddress, metadata: BookMetadata, price: u256,
    ) -> u256;
    fn get_book_metadata(self: @TState, token_id: u256) -> BookMetadata;
    fn get_book_price(self: @TState, token_id: u256) -> u256;
    fn set_book_price(ref self: TState, token_id: u256, price: u256);
    fn get_books_by_owner(self: @TState, owner: ContractAddress) -> Array<u256>;
    fn get_total_books(self: @TState) -> u256;
    fn book_exists(self: @TState, token_id: u256) -> bool;

    // Admin Functions
    fn set_base_uri(ref self: TState, base_uri: ByteArray);
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
    fn add_book_manager(ref self: TState, account: ContractAddress);
    fn remove_book_manager(ref self: TState, account: ContractAddress);
}
