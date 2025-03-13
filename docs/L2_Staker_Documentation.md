# Omni Staker spec

## How It Works

1. Users interact with the L2 contract on Base
2. The L2 contract batches and forwards transactions to L1
3. The L1 contract automatically processes received transactions
4. LayerZero handles cross-chain message passing

## Staking Methods (L2 Only)

### 1. Solo Staking
Direct staking method for individual users:
- Minimum stake: 5 USDe
- Protocol fee: 0.3%
- Instant message sending to L1
- Function: `stake_USDe(uint256 amount)`

### 2. Batch Staking
Gas-optimized group staking:
- Minimum stake: 5 USDe
- Protocol fee: 0.3%
- Batch size: (varries depending on L1 Gas price)
- Processed when batch is full
- Function: `stake_USDe_batch(uint256 amount)`
  
### 3. Unstaking 
- Coming soon!

## Technical Architecture

### L2 Contract Features
- User input validation
- Fee collection
- Batch management
- LayerZero message composition
- Gas estimation

### L1 Contract Features
- Message verification
- Automated staking execution
- Batch processing, and re-routing.
- Emergency controls
- Administrative functions

## Fee Structure

- Protocol fee: 0.3% (configurable by admin)
- LayerZero messaging fees (paid in native L2 token)
- Batch staking reduces cross-chain messaging costs

## Getting Started

1. Connect to Base network
2. Approve USDe spending for L2 contract
3. Choose staking method:
   - Solo: Higher gas, immediate processing
   - Batch: Lower gas, waiting for batch completion
4. Call appropriate function with USDe amount
5. Include required native token for cross-chain fees

## Fee Estimation

Use `estimate_fee_helper(amount, tokenAddress, isBatch)` on L2 to calculate required native token amount for cross-chain messaging.

## Support

Technical questions: [Twitter @0xOwi](https://x.com/0xOwi)
