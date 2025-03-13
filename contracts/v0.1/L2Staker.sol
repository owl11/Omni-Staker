// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
// {IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

contract L2Staker is IOAppComposer, Ownable {
    using OptionsBuilder for bytes;

    event Withdraw(address indexed user, uint32 indexed batchId, uint256 amount);
    // Events for updating state variables
    event L2OFTTokenUpdated(address indexed newAddress);
    event L2OFTStakedTokenUpdated(address indexed newAddress);
    event L1OFTTokenUpdated(address indexed newAddress);
    event ThresholdUpdated(uint256 newThreshold);
    event PenaltyFeeUpdated(uint256 newPenaltyFee);
    event Swapped(address indexed user, address tokenOut, uint256 amount);
    event msgRecieved(address Executor, bytes Executor_Data);

    error batchIdInvalid();

    address public endpoint;
    address public addressTo;
    address public L2OFTToken;
    address public L2OFTStakedToken;
    address public L1OFTToken;

    uint256 public threshold;
    uint256 public penaltyFee;
    uint256 public batchBalance;
    bytes32 private receiverAddressInBytes32;

    struct Batch {
        uint256 startUnix;
        uint256 amountTotal;
        uint256 endUnix;
        uint256 totalInSToken;
    }

    uint32 public batchId;
    mapping(uint32 => Batch) public batch;
    mapping(address => mapping(uint32 => uint256)) public balanceAtBatch;
    mapping(address => uint256[]) public userBatches;

    constructor(uint256 _threshold, address _token, address _stakedToken, address _addressTo, address _endpoint)
        Ownable(msg.sender)
    {
        receiverAddressInBytes32 = OFTComposeMsgCodec.addressToBytes32(addressTo);

        endpoint = _endpoint;
        threshold = _threshold;
        L2OFTToken = _token;
        L2OFTStakedToken = _stakedToken;
        addressTo = _addressTo;
        penaltyFee = 1 ether;
        batchId++;
    }

    function deposit(uint256 amount) public payable {
        bool success = IERC20(L2OFTToken).transferFrom(msg.sender, address(this), amount);
        if (!success) revert();
        batchBalance += amount;
        balanceAtBatch[msg.sender][batchId] += amount;

        uint256[] memory _userBatches = userBatches[msg.sender];
        uint256 length = _userBatches.length;
        if (length == 0 || _userBatches[length - 1] != batchId) {
            userBatches[msg.sender].push(batchId);
        }
    }

    function withdraw(uint32 _batchId) public {
        uint256 userBalance = balanceAtBatch[msg.sender][_batchId];
        require(userBalance > 0, "No balance to withdraw");

        // Get user's balance for the specified batch
        uint256 stakedTokenAmount = calculateUserShare(userBalance, _batchId);

        // Reset user's balance for this batch
        balanceAtBatch[msg.sender][_batchId] = 0;

        // Transfer tokens back to the user
        bool success = IERC20(L2OFTStakedToken).transfer(msg.sender, stakedTokenAmount);
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, _batchId, stakedTokenAmount);
    }

    function transferWithoutQuote(MessagingFee memory fee) public payable {
        require(batchBalance >= threshold, "Threshold not met");
        require(block.timestamp >= batch[batchId].endUnix, "not yet time");

        IOFT srcOFT = IOFT(L2OFTToken);
        bytes memory _encodedMessage = abi.encode(batchId);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 600000, 0.01 ether);
        SendParam memory sendParam = SendParam(
            40161, // You can also make this dynamic if needed
            OFTComposeMsgCodec.addressToBytes32(addressTo),
            batchBalance,
            batchBalance * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        // Ensure we don't send more than we have
        srcOFT.send{value: fee.nativeFee}(sendParam, fee, owner());
        finalizeCurrentBatch();
    }

    function estimateFee(uint256 _amount, address _OFT) public view returns (MessagingFee memory fee) {
        IOFT srcOFT = IOFT(_OFT);
        bytes memory _encodedMessage = abi.encode(1);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 600000, 0.01 ether);
        SendParam memory sendParam = SendParam(
            40161, // You can also make this dynamic if needed
            OFTComposeMsgCodec.addressToBytes32(addressTo),
            _amount,
            _amount * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        // Ensure we don't send more than we have
        fee = srcOFT.quoteSend(sendParam, false);
    }

    function calculateUserShare(uint256 userBalance, uint32 _batchId) public view returns (uint256) {
        Batch memory _batch = batch[_batchId];
        return (userBalance * _batch.totalInSToken) / _batch.amountTotal;
    }

    function withdrawETH() public onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    function finalizeCurrentBatch() internal {
        // Store the total amount deposited in the current batch
        batch[batchId].amountTotal = batchBalance;
        // Reset the total deposits for the next batch
        batchBalance = 0;
        // Increment to the next batch ID
        batchId++;
        // Initialize a new batch
        Batch storage _batch = batch[batchId];
        _batch.startUnix = block.timestamp; // Set start time to now
        _batch.endUnix = block.timestamp + 6 hours; // Set end time to 6 hours from now
    }

    function lzCompose(
        address _oApp,
        bytes32, /*_guid*/
        bytes calldata _message,
        address Executor,
        bytes calldata Executor_Data
    ) external payable override {
        require(_oApp == L2OFTStakedToken, "!oApp");
        require(msg.sender == endpoint, "!endpoint");
        bytes32 _receiver = OFTComposeMsgCodec.composeFrom(_message);

        // Extract the composed message from the delivered message using the MsgCodec
        address from = OFTComposeMsgCodec.bytes32ToAddress(_receiver);
        uint256 _amountLD = OFTComposeMsgCodec.amountLD(_message);
        uint32 pastBatchId = batchId - 1;
        uint32 _batchId = abi.decode(OFTComposeMsgCodec.composeMsg(_message), (uint32));
        if (_batchId != pastBatchId) {
            revert batchIdInvalid();
        }
        batch[pastBatchId].totalInSToken += _amountLD;
        emit msgRecieved(Executor, Executor_Data);

        emit Swapped(from, address(L2OFTStakedToken), _amountLD);
    }
    // Function to update L2OFTToken address

    function updateL2OFTToken(address _newL2OFTToken) external onlyOwner {
        zeroAdressCheck(_newL2OFTToken);
        L2OFTToken = _newL2OFTToken;
        emit L2OFTTokenUpdated(_newL2OFTToken);
    }

    // Function to update L2OFTStakedToken address
    function updateL2OFTStakedToken(address _newL2OFTStakedToken) external onlyOwner {
        zeroAdressCheck(_newL2OFTStakedToken);
        L2OFTStakedToken = _newL2OFTStakedToken;
        emit L2OFTStakedTokenUpdated(_newL2OFTStakedToken);
    }

    // Function to update L1OFTToken address
    function updateL1OFTToken(address _newL1OFTToken) external onlyOwner {
        zeroAdressCheck(_newL1OFTToken);
        L1OFTToken = _newL1OFTToken;
        emit L1OFTTokenUpdated(_newL1OFTToken);
    }

    // Function to update threshold
    function updateThreshold(uint256 _newThreshold) external onlyOwner {
        isZeroValue(_newThreshold);
        threshold = _newThreshold;
        emit ThresholdUpdated(_newThreshold);
    }

    // Function to update penalty fee
    function updatePenaltyFee(uint256 _newPenaltyFee) external onlyOwner {
        isZeroValue(_newPenaltyFee);
        penaltyFee = _newPenaltyFee;
        emit PenaltyFeeUpdated(_newPenaltyFee);
    }

    function updateAddressTo(address _addressTo) external onlyOwner {
        zeroAdressCheck(_addressTo);
        addressTo = _addressTo;
    }

    function zeroAdressCheck(address _address) private pure {
        assembly {
            if iszero(_address) {
                // revert with custom error
                mstore(0x00, 0x8aca9d85) // selector for InvalidChainID()
                revert(0x00, 0x04)
            }
        }
    }

    // Function to check if a given value is zero
    function isZeroValue(uint256 value) internal pure returns (bool) {
        return value == 0;
    }
}
