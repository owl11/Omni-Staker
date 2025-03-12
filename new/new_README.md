# Omni Staker Documentation

## Overview

Omni Staker is a cross-chain staking solution that allows users to stake USDe tokens from Layer 2 networks (Base) to Ethereum Mainnet. The protocol leverages LayerZero's cross-chain messaging to enable seamless staking operations across networks.

## Deployed Contracts

- **Contract Address**: `0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE`
  - [View on Etherscan](https://etherscan.io/address/0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE)
  - [View on Basescan](https://basescan.org/address/0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE)

## Staking Methods

### 1. Solo Staking

Direct staking method for individual users:

- Minimum stake: 5 USDe
- Protocol fee: 0.3%
- Instant processing
- Function: `stake_USDe(uint256 amount)`

### 2. Batch Staking

Grouped staking method for gas optimization:

- Minimum stake: 5 USDe
- Protocol fee: 0.3%
- Batch size: 5 users
- Processed when batch is full
- Function: `stake_USDe_batch(uint256 amount)`

## Key Features

- Cross-chain messaging via LayerZero
- Automated batch processing using Chainlink Keepers
- Protocol fee management
- Batch tracking system
- Native gas estimation helpers

## Fee Structure

- Protocol fee: 0.3% (configurable by admin)
- LayerZero messaging fees (varies based on gas prices)
- Batch staking reduces per-user gas costs

## Important Constants

- `MIN_AMOUNT`: 5 ether
- `BATCH_SIZE`: 5 users
- `MAINNET_CHAIN_ID`: 30101

## Security Features

- AccessControl for role management
- Endpoint validation
- Transfer safety checks
- Batch state management
- Cross-chain message verification

## Getting Started

To interact with Omni Staker:

1. Approve USDe token spending
2. Choose staking method (solo or batch)
3. Call appropriate staking function with desired amount
4. Include required native token for cross-chain fees

## Fee Estimation

Use `estimate_fee_helper(amount, tokenAddress, isBatch)` to get required native token amount for cross-chain messaging.

## Contact

For more information: [Twitter @0xOwi](https://x.com/0xOwi)

# Omni Staker Documentation

## Overview

Omni Staker is a cross-chain staking solution that allows users to stake USDe tokens from Layer 2 networks (Base) to Ethereum Mainnet. The protocol leverages LayerZero's cross-chain messaging to enable seamless staking operations across networks.

## Deployed Contracts

- **Contract Address**: `0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE`
  - [View on Etherscan](https://etherscan.io/address/0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE)
  - [View on Basescan](https://basescan.org/address/0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE)

## Staking Methods

### 1. Solo Staking

Direct staking method for individual users:

- Minimum stake: 5 USDe
- Protocol fee: 0.3%
- Instant processing
- Function: `stake_USDe(uint256 amount)`

### 2. Batch Staking

Grouped staking method for gas optimization:

- Minimum stake: 5 USDe
- Protocol fee: 0.3%
- Batch size: 5 users
- Processed when batch is full
- Function: `stake_USDe_batch(uint256 amount)`

## Key Features

- Cross-chain messaging via LayerZero
- Automated batch processing using Chainlink Keepers
- Protocol fee management
- Batch tracking system
- Native gas estimation helpers

## Fee Structure

- Protocol fee: 0.3% (configurable by admin)
- LayerZero messaging fees (varies based on gas prices)
- Batch staking reduces per-user gas costs

## Important Constants

- `MIN_AMOUNT`: 5 ether
- `BATCH_SIZE`: 5 users
- `MAINNET_CHAIN_ID`: 30101

## Security Features

- AccessControl for role management
- Endpoint validation
- Transfer safety checks
- Batch state management
- Cross-chain message verification

## Getting Started

To interact with Omni Staker:

1. Approve USDe token spending
2. Choose staking method (solo or batch)
3. Call appropriate staking function with desired amount
4. Include required native token for cross-chain fees

## Fee Estimation

Use `estimate_fee_helper(amount, tokenAddress, isBatch)` to get required native token amount for cross-chain messaging.

## Contact

For more information: [Twitter @0xOwi](https://x.com/0xOwi)
