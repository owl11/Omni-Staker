// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IOmniStakerL2 {
    // Events
    event SoloDeposit(address indexed sender, uint256 amount);
    event BatchDeposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed user, uint32 indexed batchId, uint256 amount);
    event BatchReceived(uint256 indexed batchId, uint256 amount);

    // Main staking functions
    function stake_USDe(uint256 amount) external payable;
    function stake_USDe_batch(uint256 amount) external payable;
    function withdraw_sUSDe_batch(uint32 _batchId) external;

    // Updated fee estimation helper
    function estimate_fee_helper(uint256 amount, address _OFTToken, bool _batch) external view returns (uint256 _fee);

    // View functions
    function calculateUserShare(uint256 userBalance, uint32 _batchId) external view returns (uint256);
    function getReadyBatches() external view returns (uint256[] memory);

    // Admin functions
    function grantKeeperRole(address account) external;
    function setProtocolFee(uint256 _newFee) external;
    function setTreasury(address _newTreasury) external;
    function updateGasCost(uint256 _newCost) external;
    function updateAddressTo(address _addressTo) external;
    function withdrawETH() external;
    function changeThreshold(uint24 _newThreshold) external;

    // Keeper functions
    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
    function stakeCrossChain(uint256 _batchId) external payable;

    // Structs
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct Batch {
        uint256 amountTotal;
        uint256 totalInSToken;
        uint24 batchSize;
        bool ready;
    }
}
