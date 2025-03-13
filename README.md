---

# OMNI Staker
Incubated during the Encode club's Ethena hackathon, and winner of [Best Use of LayerZero O-App](https://x.com/encodeclub/status/1871216983100068279)

## Overview

Omni Staker is a cross-chain staking solution enabling USDe token staking from Layer 2 networks to Ethereum Mainnet. The protocol consists of two main components:

1. L2 Contract (User-Facing) - Handles all user interactions
2. L1 Contract (Internal) - Manages mainnet staking operations

> ⚠️ Important: Users should only interact with the L2 contract. The L1 contract is system-managed and not meant for direct user interaction.

## Documentation

For detailed technical information, please refer to:
- [Omni Staker L2 Guide](./docs/L2_Staker_Documentation.md) 
- [Omni Staker L1 Guide](./docs/L1_Staker_Documentation.md)

## Architecture Overview

The system operates through two distinct layers:

### Layer 2 (User Interface)
- All user interactions happen here
- Lower gas costs
- Handles both solo and batch staking
- Manages cross-chain message composition
- Implements gas optimization strategies

### Layer 1 (System Operations)
- No direct user interaction
- Processes messages from L2
- Manages actual staking operations
- Handles protocol security and admin functions

## Contract Types

1. L2 Contract (User-Facing) - Handles all user interactions
2. L1 Contract (Internal) - Manages mainnet staking operations
> ⚠️ Important: Users should only interact with the L2 contract. The L1 contract is system-managed and not meant for direct user interaction.

## Key Features

- Cross-chain messaging via LayerZero
- Dynamic batch sizing based on gas prices
- Protocol fee management (0.3%)
- Gas estimation helpers
- Emergency controls and admin functions

## Try it out

> ⚠️ WARNING: CONTRACTS ARE IN BETA, NOT AUDITED, USE WITH CAUTION

## Deployed Contracts

### Layer 2 (Base) - User Interface Contract
- **Contract Address**: `0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE`
- [View on Basescan](https://basescan.org/address/0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE)

### Layer 1 (Ethereum) - System Contract
- **Contract Address**: `0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE`
- [View on Etherscan](https://etherscan.io/address/0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE)
- ⚠️ Do not interact directly with this contract

## Development Status

- ✅ Solo staking implementation
- ✅ Batch staking implementation
- 🔄 Unstaking functionality (in progress)
- 🔄 Additional gas optimizations
- 🔄 Enhanced batch processing
- 🔄 Security review

## References

1. [LayerZero OApp Patterns](https://docs.layerzero.network/v2/developers/evm/oft/oft-patterns-extensions)
2. [ERC-4626 Standard](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626)
3. [Ethena Testnet Info](https://drive.google.com/file/d/1NR35yYpZV6m4eZOHr4WgIy4U9IyIOhjt/view)

## Contact

Technical support: [Twitter @0xOwi](https://x.com/0xOwi)
