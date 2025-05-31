#[starknet::contract]
pub mod BookNFT {
    use starknet::{
        ContractAddress, ClassHash, get_caller_address,
        storage::{
            StoragePointerWriteAccess, StoragePointerReadAccess, Map, StorageMapReadAccess,
            StorageMapWriteAccess,
        },
    };
    use core::num::traits::zero::Zero;
    use core::array::ArrayTrait;
    use scriptchain::{
        interfaces::ibook::{IBookNFT, BookMetadata}, types::BookNFTErrors as Errors,
        components::access_control::AccessControlComponent,
    };
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::introspection::{src5::SRC5Component};
    use openzeppelin::upgrades::UpgradeableComponent;

    // Components
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Interface implementations
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721METAImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalFunctions<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Book-specific storage
        book_metadata: Map<u256, BookMetadata>,
        book_prices: Map<u256, u256>,
        owner_tokens: Map<(ContractAddress, u256), u256>, // (owner, index) -> token_id
        owner_token_count: Map<ContractAddress, u256>,
        last_minted_id: u256,
        base_uri: ByteArray,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        BookMinted: BookMinted,
        BookPriceUpdated: BookPriceUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BookMinted {
        #[key]
        pub token_id: u256,
        #[key]
        pub owner: ContractAddress,
        pub title: ByteArray,
        pub author: ByteArray,
        pub price: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BookPriceUpdated {
        #[key]
        pub token_id: u256,
        pub old_price: u256,
        pub new_price: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
    ) {
        // Initialize OpenZeppelin components
        self.erc721.initializer(name, symbol, base_uri.clone());
        self.access_control.initializer(admin);

        // Initialize book-specific storage
        self.base_uri.write(base_uri);
        self.last_minted_id.write(0);
    }

    // *************************************************************************
    //                         BOOK NFT IMPLEMENTATION
    // *************************************************************************
    #[abi(embed_v0)]
    impl BookNFTImpl of IBookNFT<ContractState> {
        // Book-specific functions
        fn mint_book(
            ref self: ContractState, to: ContractAddress, metadata: BookMetadata, price: u256,
        ) -> u256 {
            // Access control check - only BookManager role can mint
            self.access_control.only_role(3); // BookManager role

            assert(!to.is_zero(), Errors::ZERO_ADDRESS);
            assert(metadata.title.len() > 0, Errors::INVALID_METADATA);
            assert(metadata.author.len() > 0, Errors::INVALID_METADATA);

            let token_id = self.last_minted_id.read() + 1;
            self.last_minted_id.write(token_id);

            // Mint using OpenZeppelin's ERC721
            self.erc721.mint(to, token_id);

            // Store book metadata and price
            self.book_metadata.write(token_id, metadata.clone());
            self.book_prices.write(token_id, price);

            // Update owner tokens mapping
            let owner_count = self.owner_token_count.read(to);
            self.owner_tokens.write((to, owner_count), token_id);
            self.owner_token_count.write(to, owner_count + 1);

            // Emit book-specific event
            self
                .emit(
                    BookMinted {
                        token_id,
                        owner: to,
                        title: metadata.title.clone(),
                        author: metadata.author.clone(),
                        price,
                    },
                );

            token_id
        }

        fn get_book_metadata(self: @ContractState, token_id: u256) -> BookMetadata {
            assert(self.erc721.exists(token_id), Errors::TOKEN_NOT_EXISTS);
            self.book_metadata.read(token_id)
        }

        fn get_book_price(self: @ContractState, token_id: u256) -> u256 {
            assert(self.erc721.exists(token_id), Errors::TOKEN_NOT_EXISTS);
            self.book_prices.read(token_id)
        }

        fn set_book_price(ref self: ContractState, token_id: u256, price: u256) {
            let owner = self.erc721.owner_of(token_id);
            let caller = get_caller_address();
            assert(caller == owner, Errors::NOT_OWNER);

            let old_price = self.book_prices.read(token_id);
            self.book_prices.write(token_id, price);

            self.emit(BookPriceUpdated { token_id, old_price, new_price: price });
        }

        fn get_books_by_owner(self: @ContractState, owner: ContractAddress) -> Array<u256> {
            let mut books = ArrayTrait::new();
            let count = self.owner_token_count.read(owner);

            let mut i: u256 = 0;
            loop {
                if i >= count {
                    break;
                }
                let token_id = self.owner_tokens.read((owner, i));
                books.append(token_id);
                i += 1;
            };

            books
        }

        fn get_total_books(self: @ContractState) -> u256 {
            self.last_minted_id.read()
        }

        fn book_exists(self: @ContractState, token_id: u256) -> bool {
            self.erc721.exists(token_id)
        }

        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            self.access_control.only_admin();
            self.base_uri.write(base_uri);
        }

        fn get_base_uri(self: @ContractState) -> ByteArray {
            self.base_uri.read()
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.access_control.only_admin();
            self.upgradeable.upgrade(new_class_hash);
        }

        fn add_book_manager(ref self: ContractState, account: ContractAddress) {
            self.access_control.grant_role(3, account); // BookManager role
        }

        fn remove_book_manager(ref self: ContractState, account: ContractAddress) {
            self.access_control.revoke_role(3, account); // BookManager role
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _update_owner_tokens_on_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
        ) {
            if from.is_zero() {
                // Minting - already handled in mint_book
                return;
            }

            // Remove from previous owner's list
            let from_count = self.owner_token_count.read(from);
            let mut found_index = from_count;

            let mut i: u256 = 0;
            loop {
                if i >= from_count {
                    break;
                }
                if self.owner_tokens.read((from, i)) == token_id {
                    found_index = i;
                    break;
                }
                i += 1;
            };

            // Move last token to found position and decrease count
            if found_index < from_count {
                let last_token = self.owner_tokens.read((from, from_count - 1));
                self.owner_tokens.write((from, found_index), last_token);
                self.owner_token_count.write(from, from_count - 1);
            }

            // Add to new owner's list
            let to_count = self.owner_token_count.read(to);
            self.owner_tokens.write((to, to_count), token_id);
            self.owner_token_count.write(to, to_count + 1);
        }
    }
}

