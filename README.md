---

# OMNI Staker

## Overview

Omni Staker implements a decentralized staking and unstaking mechanism, utilizing the staked token standard ERC4626, and Layer Zero OFT standard. We bring a solution to users in L2's to interact with the staked assets as if they were on the host chain (ETH), but it can work for any chain with a staked asset and OFT capabilities.

Users can stake tokens and withdraw rewards seamlessly through a series of smart contracts. The architecture consists of four contracts, which can be divided into pairs: two for the Layer 1 and Layer 2 staking with batch processing, and two solo counterpart contracts that handle individual user transactions without batching. This design caters to both users who prefer the efficiency of batch processing and those who prefer immdeiate finality.

## Workflow Overview

### Starting on Layer 2

The workflow begins on Layer 2, where users can stake their tokens in a more cost-effective manner compared to Layer 1. By leveraging Layer Zero, users benefit from significantly lower gas fees by batching the mint and redeem functions of many users. The process is designed to be user-friendly, allowing multiple users to stake their tokens simultaneously in batches.

1. **User Staking**: Users deposit their tokens into the L2 Staker contract, which aggregates these deposits into batches.

2. **Batch Processing**: The contract manages multiple user stakes, optimizing gas costs and simplifying reward distribution.

3. **Reward Calculation**: Rewards are calculated based on each user's proportional stake within the batch, ensuring fair distribution.

4. **Withdrawal Mechanism**: Users can easily withdraw their rewards in USDE, reflecting the higher value of their staked sUsde tokens.

### Transitioning to Layer 1

Once the batch is queued and sent on Layer 2, The L1 contract handles the message accordingly, be it a stake or a redeem, with unstakes/redeems inserted into the withdrawal queue and direct stakes exchanges for their staked counterpart.

## Contracts

### 1. L2 Staker Contract

The L2 Staker contract allows users to stake tokens on a Layer 2 network. It manages multiple users' stakes in batches, optimizing gas costs and simplifying the withdrawal process. Key features include:

- **Batch Processing**: Users can deposit tokens in batches, allowing for efficient management of multiple stakes.
- **Reward Calculation**: The contract calculates the balance in staked tokens for each user based on their proportional stake within the batch.
- **Withdrawal Mechanism**: Users can withdraw their staked tokens in a straightforward manner, ensuring they receive the correct amount based on their deposited/staked amount.

### 2. L1 Staker Contract

The L1 Staker contract handles requests sent by the L2 contract and processes them efficiently using LayerZero messaging protocol. It provides enhanced security and finality while allowing users to manage their stakes effectively. Key features include:

- **Handles L2 Requests**: The L1 contract consumes messages sent from the L2 contract via Layer Zero, by using the OApp compose interface, it fetches details about user withdrawals, deposits or state updates.
- **Accurate Balance Management**: When a request is received from L2, the L1 contract queries the fetched balance and calculates how much `SUSD` or staked token to return based on current that amount without friction.

### 3. Solo L2 Staker Contract

The Solo L2 Staker contract enables users to stake tokens individually without batching. Each user pays for their own transaction fees, providing a more customized staking experience.

- #### Key features include:

- **Individual Transactions**: Users can stake and withdraw tokens independently, allowing for greater control over their funds.
- **Direct Fee Payment**: Users are responsible for their own gas fees, which can be beneficial for those who prefer not to share costs with others.
- **Direct user transfers**: unlike the batched version, users receive their tokens in their wallets after deposits and withdrawals (after the cooldown period), meaning users don't need to interact with the contract to withdraw their share.

### 4. Solo L1 Staker Contract

Much like the earlier L1 staker, but tailored for individual uses, users send their tokens through the L2 contract or directly, using Layer Zero's OFT, and the contract handles the operation accordingly.

- **Independent Staking**: Users can manage their stakes without relying on batch processes.
- **Lower Transaction Costs**: While interacting with Layer 1 directly, users benefit from optimized gas usage during individual transactions.

## Functionality

### Batching Mechanism

L2Staker utilizes a batching mechanism that allows multiple users to stake their tokens together. This approach optimizes gas usage and simplifies the process of staking tokens, especially for users outpriced from the ETH mainnet, allowing users to interact with L1 protocols with less fees than anticipated.

### Balance tracking

The contracts implement a robust calculation system that ensures users receive accurate amounts based on their stakes. The formula used takes into account both the user's balance and the total amounts of staked tokens in each batch.

### User Withdrawals

Users can withdraw their rewards easily through dedicated functions in each contract. The withdrawal process is designed to ensure that users receive their correct share of rewards based on their proportional stake.

## Test it?

Though most of the work remains a WIP (BUGS MAY EXIST, PROCEED WITH CAUTION, THIS CODE HAS NOT BEEN AUDITED).

You can try the contracts in Ethena Ble testnet:
https://testnet.explorer.ethena.fi/address/0x01f46253bC7011990AB1D8e8D996ED9700ee2Ae0?tab=read_contract

and the corrosponding L1 contract, which traditionally requires no user interaction after the L2 transaction has been deposited:
https://sepolia.etherscan.io/search?f=0&q=0xd71FEf1Ba351c413Cf7E8D91cBC8EbfcBa10F2E1 (WIP)

The solo staker contracts, meanwhile, provide immediate stakes, and unstake requests, but require further optimization, with L2 Solo staker delpoyed at :

https://testnet.explorer.ethena.fi/address/0x16BCB084B2dDEc17bFE4f1EF6d5cB769967D3Cd3?tab=contract

And again, the L1 Solo Staker, which works side by side with the L2Staker, but can also work independently, where sending tokens directly to it would incur the required operation, be it a stake, an unstake request, or an unstake one cooldown has passed :
https://sepolia.etherscan.io/search?f=0&q=0x2542b59b5b7bd401671a7a97954a85bfa1f6823d (WIP)

The script folder attached provides a solid starting point for interacting with the protocol, from staking and unstaking all the way to deployment at specific nonce, and permissioned functionalities expected to not be used unless an upgrade or as an emergency circuit breaker.

## Further info

The current state of the contracts is good, but more work is needed, the solo staker handles all types of operations (though further optimization would be ideal), whereas the batcher version only handles stakes since the complexity of handling Batched unstakes alongside their respective unstake requests once the cooldown period passed adds additional overhead fortunately, any additional compelxities may remain on the L2 side of things, keeping transactions affordable for all users.

Citations:
[1] https://docs.layerzero.network/v2/developers/evm/oft/oft-patterns-extensions
[2] https://ethereum.org/en/developers/docs/standards/tokens/erc-4626
[3] Ethena Ble testnet network information https://drive.google.com/file/d/1NR35yYpZV6m4eZOHr4WgIy4U9IyIOhjt/view
