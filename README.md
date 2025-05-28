````markdown
# 📜 ScriptChain Smart Contracts

This repository contains the smart contracts powering **ScriptChain**, a blockchain-based literature platform that rewards reader engagement, manages book ownership, enables interactive games, and integrates tokenized incentives.

Built on **Starknet** using **Cairo 1.0**, these contracts are designed for secure, transparent, and scalable interactions between users and the platform.

---

## 🔒 Core Contracts

| Contract Name         | Description |
|-----------------------|-------------|
| `RewardToken.cairo`   | ERC20-style token contract to reward user engagement. |
| `EngagementRewarder.cairo` | Tracks reading activity and distributes tokens to readers. |
| `QuizGame.cairo`      | Quiz/prediction game logic with on-chain rewards. |
| `BookNFT.cairo`       | Optional ERC721 contract for tokenized book ownership. |
| `Marketplace.cairo`   | Book marketplace accepting crypto payments. |
| `AccessControl.cairo` | Role-based permissions (admin, reader, oracle, etc.). |

---

## 🧰 Tools & Requirements

- [Starknet/Cairo 1.0](https://book.cairo-lang.org/)
- [Protostar](https://docs.swmansion.com/protostar/)
- [Starkli](https://github.com/xJonathanLEI/starkli) (optional CLI)
- Python ≥ 3.8 for local scripts/tests

---

## 🛠️ Setup & Compilation

### Clone the Repo

```bash
git clone https://github.com/yourusername/scriptchain-contracts.git
cd scriptchain-contracts
````

### Install Protostar

```bash
curl -L https://raw.githubusercontent.com/software-mansion/protostar/master/install.sh | bash
source ~/.bashrc
```

### Build Contracts

```bash
protostar build
```

---

## 🚀 Deployment

Update your `protostar.toml` or CLI args with your Starknet RPC and wallet details.

```bash
protostar deploy ./build/RewardToken.json
protostar deploy ./build/EngagementRewarder.json
```

For testnet (e.g., Sepolia or Starknet Testnet):

```bash
protostar deploy ./build/RewardToken.json --network testnet
```

---

## 🧪 Testing

All tests are written in Cairo using `protostar`.

```bash
protostar test ./tests
```

---

## 📁 Folder Structure

```
contracts/
├── RewardToken.cairo
├── EngagementRewarder.cairo
├── QuizGame.cairo
├── BookNFT.cairo
├── AccessControl.cairo
└── Marketplace.cairo

tests/
├── test_reward_token.cairo
├── test_engagement_rewarder.cairo
└── ...
```

---

## 🔐 Security Notes

* Follows Starknet best practices for access control, upgradability, and gas efficiency.
* Includes pause mechanisms and role checks for critical functions.
* Formal audits will be conducted prior to mainnet deployment.

---

## 🧭 Roadmap

* [x] Deploy testnet `RewardToken`
* [x] Build & test `EngagementRewarder`
* [x] Integrate quiz logic into `QuizGame`
* [ ] Implement book purchase logic in `Marketplace`
* [ ] Add DAO-style voting for community proposals

---

## 📜 License

MIT License © 2025 ScriptChain Contributors

---

## 🤝 Contributing

PRs and suggestions are welcome! See `CONTRIBUTING.md` for coding standards and review process.

```


