//reward token

use openzeppelin::token::erc20::{ERC20, ERC20Impl};

#[contract]
contract RewardToken is ERC20Impl {
    constructor(name: String, symbol: String, decimals: u8) {
        ERC20Impl::initialize(name, symbol, decimals);
    }
}