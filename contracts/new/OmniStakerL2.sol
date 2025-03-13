/**
 * @title Omni Staker Layer 2 Contract
 * @notice A staking contract that handles both solo and batch staking operations on L2 networks
 * @dev Implements LayerZero cross-chain messaging and OFT token transfers
 *
 * @custom:contact x.com/0xOwi
 *
 * @notice This contract allows users to:
 * - Stake USDe tokens individually or in batches
 * - Withdraw staked tokens (sUSDe)
 * - Handle cross-chain message composition
 * - Manage protocol fees and treasury
 *
 * @dev Key features:
 * - Minimum staking amount: 5 ether
 * - Protocol fee: Configurable (default 0.3%)
 * - Batch threshold: 5 users, can be changed
 * - Supports both solo and batch staking modes
 *
 * @dev Security considerations:
 * - Uses AccessControl for role-based permissions
 * - Validates endpoints and addresses
 * - Includes safety checks for transfers and fees
 *
 * @dev State Management:
 * - Tracks individual and batch balances
 * - Manages batch states including size and readiness
 * - Handles cross-chain message composition
 *
 * @notice Important constants:
 * - SOLO_STAKING = 1
 * - BATCH_STAKING = 2
 * - KEEPER_ROLE = keccak256("KEEPER_ROLE")
 * - MAINNET_CHAIN_ID = 30101
 *
 * @dev Dependencies:
 * - OpenZeppelin: AccessControl, IERC20
 * - LayerZero: OApp, IOFT, OptionsBuilder
 * - Custom: GasPriceOracle interface
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OApp, Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IOFT, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AutomationCompatibleInterface} from "./chainlinkKeepers/AutomationCompatibleInterface.sol";

error InvalidAmount();
error TransferFailed();
error InsufficientNativeFee();
error ZeroAddress();
error InvalidEndpoint();

contract OmniStakerL2 is IOAppComposer, AccessControl, AutomationCompatibleInterface {
    using OptionsBuilder for bytes;

    // Events
    event SoloDeposit(address indexed sender, uint256 amount);
    event BatchDeposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed user, uint32 indexed batchId, uint256 amount);
    event BatchReceived(uint256 indexed batchId, uint256 amount);

    // Constants
    uint128 constant MIN_AMOUNT = 5 ether;
    uint128 constant LZ_TOKEN_TRANSFER_COST = 80000;
    uint32 constant MAINNET_CHAIN_ID = 30101;
    uint8 public constant SOLO_STAKING = 0;
    uint8 public constant BATCH_STAKING = 1;
    uint256 public constant PLACEHOLDER = 1;
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    // State Variables
    GasPriceOracle private constant gasPriceOracle = GasPriceOracle(0x420000000000000000000000000000000000000F);
    address public immutable localEndpoint;
    address public treasury;
    address public L2OFTToken;
    address public L2OFTStakedToken;
    address public addressTo;
    bytes32 private receiverAddressInBytes32;
    uint256 public TYPE_1_GAS_COST = 500_000;
    uint256 public batchBalance;
    uint256 public threshold = 5;
    uint256 public batchId;
    uint256 public protocolFee;

    // Mappings
    mapping(address => mapping(uint256 => uint256)) public balanceAtBatch;
    mapping(address => uint256[]) public userBatches;
    mapping(uint256 => Batch) public batch;

    // Structs
    struct Batch {
        uint256 amountTotal;
        uint256 totalInSToken;
        uint24 batchSize;
        bool ready;
    }

    // Constructor
    constructor(address _endpoint, address _token, address _stakedToken, address _addressTo) {
        if (_token == address(0) || _stakedToken == address(0) || _addressTo == address(0)) {
            revert ZeroAddress();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        localEndpoint = _endpoint;
        treasury = msg.sender;
        L2OFTToken = _token;
        protocolFee = 30;
        L2OFTStakedToken = _stakedToken;
        addressTo = _addressTo;
        receiverAddressInBytes32 = OFTComposeMsgCodec.addressToBytes32(_addressTo);
        batchId++;
    }

    // External/Public Functions
    function stake_USDe(uint256 amount) external payable {
        if (amount < MIN_AMOUNT) revert InvalidAmount();
        IERC20 token = IERC20(L2OFTToken);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
        uint256 fee = calculateProtocolFee(amount);
        uint256 amountAfterFee = amount - fee;
        success = IERC20(L2OFTToken).transfer(treasury, fee);
        if (!success) revert TransferFailed();

        _prepareAndSendOFT(L2OFTToken, amountAfterFee);
        emit SoloDeposit(msg.sender, amountAfterFee);
    }

    function stake_USDe_batch(uint256 amount) external payable {
        if (amount < MIN_AMOUNT) revert InvalidAmount();

        uint256 _protocolFee = calculateProtocolFee(amount);
        uint256 amountAfterFee = amount - _protocolFee;

        bool success = IERC20(L2OFTToken).transferFrom(msg.sender, treasury, _protocolFee);
        if (!success) revert InsufficientNativeFee();

        MessagingFee memory fee = estimateOFTFeeBatch(amountAfterFee, L2OFTToken);
        uint256 _fee = fee.nativeFee / threshold;

        (success,) = address(this).call{value: _fee}("");
        if (!success) revert InsufficientNativeFee();

        success = IERC20(L2OFTToken).transferFrom(msg.sender, address(this), amountAfterFee);
        if (!success) revert();

        _prepareAndCheckBatch(amountAfterFee);
        emit BatchDeposit(msg.sender, amountAfterFee);
    }

    function estimate_fee_helper(uint256 amount, address _OFTToken, bool _batch) public view returns (uint256 _fee) {
        MessagingFee memory fee;
        if (!_batch) {
            fee = estimateOFTFeeSolo(amount, _OFTToken);
        } else {
            fee = estimateOFTFeeBatch(amount, _OFTToken);
        }
        _fee = fee.nativeFee;
    }

    function withdraw_sUSDe_batch(uint32 _batchId) external {
        uint256 userBalance = balanceAtBatch[msg.sender][_batchId];
        require(userBalance > 0, "No balance to withdraw");

        uint256 stakedTokenAmount = calculateUserShare(userBalance, _batchId);
        balanceAtBatch[msg.sender][_batchId] = 0;

        bool success = IERC20(L2OFTStakedToken).transfer(msg.sender, stakedTokenAmount);
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, _batchId, stakedTokenAmount);
    }

    function lzCompose(
        address _oApp,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*Executor*/
        bytes calldata /*Executor Data*/
    ) external payable override {
        if (msg.sender != localEndpoint) revert InvalidEndpoint();
        if (_oApp != L2OFTStakedToken) revert InvalidEndpoint();
        (uint256 id, address sender) = abi.decode(OFTComposeMsgCodec.composeMsg(_message), (uint256, address));
        bytes32 _senderBytes32 = OFTComposeMsgCodec.addressToBytes32(sender);
        uint256 _amountLD = OFTComposeMsgCodec.amountLD(_message);
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
        if (_senderBytes32 != receiverAddressInBytes32 || srcEid != MAINNET_CHAIN_ID) revert InvalidEndpoint();
        Batch storage _batch = batch[id];
        _batch.totalInSToken = _amountLD;
        emit BatchReceived(id, _amountLD);
    }

    // Admin Functions
    function grantKeeperRole(address account) external {
        grantRole(KEEPER_ROLE, account);
    }

    function stakeCrossChain(uint256 _batchId) public payable onlyRole(KEEPER_ROLE) {
        require(batch[_batchId].ready, "batch not ready");

        IOFT srcOFT = IOFT(L2OFTToken);
        bytes memory _encodedMessage = abi.encode(_batchId, address(this));
        uint256 finalCost = _calculateGasCostLzSend();

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0)
            .addExecutorLzComposeOption(0, uint128(TYPE_1_GAS_COST), uint128(finalCost));
        SendParam memory sendParam = SendParam(
            MAINNET_CHAIN_ID,
            OFTComposeMsgCodec.addressToBytes32(addressTo),
            batchBalance,
            batchBalance * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        MessagingFee memory fee = srcOFT.quoteSend(sendParam, false);

        srcOFT.send{value: fee.nativeFee}(sendParam, fee, address(this));
    }

    function setProtocolFee(uint256 _newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newFee <= 100, "Fee cannot exceed 1%");
        protocolFee = _newFee;
    }

    function setTreasury(address _newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _newTreasury;
    }

    function updateGasCost(uint256 _newCost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TYPE_1_GAS_COST = _newCost;
    }

    function updateAddressTo(address _addressTo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_addressTo == address(0)) revert ZeroAddress();
        addressTo = _addressTo;
        receiverAddressInBytes32 = OFTComposeMsgCodec.addressToBytes32(_addressTo);
    }
    //  checkUpkeep function

    function checkUpkeep(bytes calldata /* checkData */ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256[] memory readyBatches = getReadyBatches();
        if (readyBatches.length > 0) {
            upkeepNeeded = true;
            // Get the first ready batch
            performData = abi.encode(readyBatches[0]);
        } else {
            upkeepNeeded = false;
        }
    }

    function getReadyBatches() public view returns (uint256[] memory) {
        uint256[] memory readyBatches = new uint256[](batchId);
        uint256 count = 0;
        for (uint256 i = 0; i < batchId; i++) {
            if (batch[i].ready) {
                readyBatches[count] = i;
                count++;
            }
        }
        return readyBatches;
    }

    //  performUpkeep function
    function performUpkeep(bytes calldata performData) external override {
        uint256 _batchId = abi.decode(performData, (uint256));
        require(batch[_batchId].ready, "Batch is not ready");
        if (batch[_batchId].ready) {
            stakeCrossChain(_batchId);
            batch[_batchId].ready = false;
        }
    }

    function withdrawETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    function changeThreshold(uint24 _newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        threshold = _newThreshold;
    }

    // Public View Functions
    function estimateOFTFeeSolo(uint256 _amount, address _OFT) public view returns (MessagingFee memory fee) {
        bytes memory _encodedMessage = abi.encode(0, msg.sender);
        uint256 finalCost = _calculateGasCostLzSend();

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_TOKEN_TRANSFER_COST, 0)
            .addExecutorLzComposeOption(0, uint128(TYPE_1_GAS_COST), uint128(finalCost));

        SendParam memory sendParam = _createSendParam(_amount, _extraOptions, _encodedMessage);
        fee = IOFT(_OFT).quoteSend(sendParam, false);
    }

    function estimateOFTFeeBatch(uint256 _amount, address _OFT) public view returns (MessagingFee memory fee) {
        bytes memory _encodedMessage = abi.encode((batchId - 1), address(this));
        uint256 finalCost = _calculateGasCostLzSend();

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_TOKEN_TRANSFER_COST, 0)
            .addExecutorLzComposeOption(0, uint128(TYPE_1_GAS_COST), uint128(finalCost));

        SendParam memory sendParam = _createSendParam(_amount, _extraOptions, _encodedMessage);
        fee = IOFT(_OFT).quoteSend(sendParam, false);
    }

    function calculateUserShare(uint256 userBalance, uint32 _batchId) public view returns (uint256) {
        Batch memory _batch = batch[_batchId];
        return (userBalance * _batch.totalInSToken) / _batch.amountTotal;
    }

    function adjustThreshold() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 gasPrice = gasPriceOracle.l1BaseFee();
        if (gasPrice > 5 gwei) {
            threshold = 3;
        } else if (gasPrice > 15 gwei) {
            threshold = 5;
        } else if (gasPrice > 30 gwei) {
            threshold = 10;
        }
    }

    // Internal Functions
    function _calculateGasCostLzSend() internal view returns (uint256) {
        uint256 gasPrice = gasPriceOracle.l1BaseFee();
        if (gasPrice == 0) {
            revert();
        }
        return TYPE_1_GAS_COST * gasPrice;
    }

    function _createSendParam(uint256 amount, bytes memory extraOptions, bytes memory encodedMessage)
        internal
        view
        returns (SendParam memory)
    {
        return SendParam(
            MAINNET_CHAIN_ID, receiverAddressInBytes32, amount, amount * 9 / 10, extraOptions, encodedMessage, ""
        );
    }

    function _prepareAndSendOFT(address token, uint256 amount) internal {
        // Encode the solo stake identifier accompanied by the sender (must match fee estimation)
        bytes memory encodedMessage = abi.encode(0, msg.sender);
        uint256 finalCost = _calculateGasCostLzSend();
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_TOKEN_TRANSFER_COST, 0)
            .addExecutorLzComposeOption(0, uint128(TYPE_1_GAS_COST), uint128(finalCost));
        SendParam memory sendParam = _createSendParam(amount, extraOptions, encodedMessage);
        // Use the same send param to quote the fee
        MessagingFee memory fee = IOFT(token).quoteSend(sendParam, false);
        IOFT(token).send{value: fee.nativeFee}(sendParam, fee, msg.sender);
    }

    function _prepareAndCheckBatch(uint256 amount) internal {
        batchBalance += amount;
        balanceAtBatch[msg.sender][batchId] += amount;
        uint256[] memory userBatch = userBatches[msg.sender];
        if (userBatch[userBatch.length - PLACEHOLDER] != batchId) {
            userBatches[msg.sender].push(batchId);
            batch[batchId].batchSize++;
        }
        if (batch[batchId].batchSize > threshold) {
            batch[batchId].ready = true;
            finalizeCurrentBatch();
        }
    }

    function finalizeCurrentBatch() internal {
        batch[batchId].amountTotal = batchBalance;
        //totalInSToken = PLACEHOLDER (1) used to make the change by lzCompose to a non-zero value
        // so that the change is considered warm when the cross chain message is executed
        batch[batchId].totalInSToken = PLACEHOLDER;
        batchBalance = 0;
        batchId++;
        Batch storage _batch = batch[batchId];
        _batch.amountTotal = 0;
    }

    function calculateProtocolFee(uint256 amount) internal view returns (uint256) {
        return (amount * protocolFee) / 10000;
    }
}

interface GasPriceOracle {
    function l1BaseFee() external view returns (uint256);
}
