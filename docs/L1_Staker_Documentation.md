# Multi-Chain Omni Staker Documentation

## Overview

Omni Staker is a universal cross-chain staking solution that enables any Layer 2 or alternative chain to interact with Ethereum Mainnet staking protocols. Using LayerZero's OApp compose pattern, it can integrate with any chain that supports LayerZero messaging.

## Deployed Contract

- **Contract Address**: `0xC0c0EbfC83e9E9d1A2ED809B4F841BcFB58ACEFE`
  - Nearly identical address across all supported chains
  - Currently active on Ethereum and Base
  - Expandable to any LayerZero-supported chain with OFT Compose capabilities

## Cross-Chain Integration Requirements

### For New Chain Integration

1. LayerZero Endpoint on target chain
2. Support for OFT (Omnichain Fungible Token)
3. Gas estimation capabilities
4. Compose message support

## Key Features

### 1. Universal Compatibility

- Works with any EVM chain
- Chain-agnostic message passing

### 2. Standardized Gas Management

- Automatic gas estimation across chains
- Dynamic fee adjustment based on destination chain
- Built-in gas price oracle integration

### 3. Unified State Management

- Consistent batch processing across chains
- Synchronized staking operations
- Cross-chain balance tracking

## Integration Guide

### 1. Setup Requirements

```solidity
// Required on new chain
address LZ_ENDPOINT;
address OFT_TOKEN;
address stakedOFT_TOKEN;
```

### 2. Message Structure

- Batch ID tracking
- Source verification
- Amount validation
- Gas estimation

### 3. Gas Configuration

```solidity
uint256 GAS_FOR_RELAY = 500_000;
uint256 GAS_FOR_CALL = 65_000;
```

## Security Considerations

### Cross-Chain Verification

- Source chain validation
- Message origin verification
- Amount validation
- Gas limit checks

### State Management

- Atomic operations
- Rollback mechanisms
- Balance reconciliation

## Gas Optimization

### Dynamic Batch Sizing

- Adjusts based on destination gas prices
- Optimizes for cross-chain messaging costs
- Balances efficiency with speed

### Message Compression

- Minimal payload size
- Optimized encoding
- Efficient state updates

## Contact & Support

For integration support: [Twitter @0xOwi](https://x.com/0xOwi)

## References

1. [LayerZero Endpoints](https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids)
2. [OApp Documentation](https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids)
3. [Cross-Chain Standards](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626)
