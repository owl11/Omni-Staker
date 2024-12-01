// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
// {IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

contract L2StakerSolo is Ownable {
    using OptionsBuilder for bytes;

    // Events for updating state variables
    event L2OFTTokenUpdated(address indexed newAddress);
    event L2OFTStakedTokenUpdated(address indexed newAddress);
    event ThresholdUpdated(uint256 newThreshold);

    event Swapped(address indexed user, address tokenOut, uint256 amount);
    event msgRecieved(address Executor, bytes Executor_Data);

    error transferFailed();

    address public localEndpoint;
    address public addressTo;
    address public L2OFTToken;
    address public L2OFTStakedToken;
    // address public L1OFTToken;

    uint8 public constant STAKE = 1;
    uint8 public constant UNSTAKE = 2;
    uint128 constant minAmt = 1 ether;

    uint256 public threshold;
    bytes32 private receiverAddressInBytes32;

    constructor(address _token, address _stakedToken, address _addressTo, address _endpoint) Ownable(msg.sender) {
        receiverAddressInBytes32 = OFTComposeMsgCodec.addressToBytes32(addressTo);
        localEndpoint = _endpoint;
        // threshold = 50 ether;
        L2OFTToken = _token;
        L2OFTStakedToken = _stakedToken;
        addressTo = _addressTo;
    }

    function depositUSDERecieveSUSD(uint256 amount, MessagingFee memory fee) public payable {
        require(amount >= minAmt, "Threshold not met");
        bytes memory _encodedMessage = abi.encode(OFTComposeMsgCodec.addressToBytes32(msg.sender));

        bool success = IERC20(L2OFTToken).transferFrom(msg.sender, address(this), amount);
        if (!success) revert transferFailed();
        // uint256 amountAfterFee = calculateAmountMinusFee(amount);
        IOFT srcOFT = IOFT(L2OFTToken);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0)
            .addExecutorLzComposeOption(0, 300000, 0.003 ether);
        SendParam memory sendParam = SendParam(
            40161,
            OFTComposeMsgCodec.addressToBytes32(addressTo),
            amount,
            amount * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        srcOFT.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
    }

    function depositSUSDStartCountdown(uint256 amount, MessagingFee memory fee) public payable {
        require(amount >= minAmt, "Threshold not met");
        bytes memory _encodedMessage = abi.encode(OFTComposeMsgCodec.addressToBytes32(msg.sender));

        bool success = IERC20(L2OFTStakedToken).transferFrom(msg.sender, address(this), amount);
        if (!success) revert transferFailed();
        // uint256 amountAfterFee = calculateAmountMinusFee(amount);
        IOFT srcOFT = IOFT(L2OFTStakedToken);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0)
            .addExecutorLzComposeOption(0, 300000, 0.003 ether);
        SendParam memory sendParam = SendParam(
            40161,
            OFTComposeMsgCodec.addressToBytes32(addressTo),
            amount,
            amount * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        srcOFT.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
    }

    function sendUnstakeMessage(MessagingFee memory fee) public payable {
        // we use 1 USDE to send a messsage to the L1 contract, this way we are getting a fair fee for each transfer
        bytes memory _encodedMessage = abi.encode(OFTComposeMsgCodec.addressToBytes32(msg.sender));

        bytes memory _extraOptions;
        SendParam memory sendParam;
        bool success = IERC20(L2OFTToken).transferFrom(msg.sender, address(this), minAmt);
        if (!success) revert transferFailed();
        // uint256 amountAfterFee = calculateAmountMinusFee(amount);
        IOFT srcOFT = IOFT(L2OFTToken);

        _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(100000, 0).addExecutorLzComposeOption(
            0, 300000, 0.003 ether
        );
        sendParam = SendParam(
            40161,
            OFTComposeMsgCodec.addressToBytes32(addressTo),
            minAmt,
            minAmt * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        srcOFT.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
    }

    function estimateLZFee(uint256 _amount, IOFT _OFT) public view returns (MessagingFee memory fee) {
        bytes memory _encodedMessage = abi.encode(1);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 300000, 0.003 ether);
        SendParam memory sendParam = SendParam(
            40161, // You can also make this dynamic if needed
            receiverAddressInBytes32,
            _amount,
            _amount * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        // Ensure we don't send more than we have
        fee = _OFT.quoteSend(sendParam, false);
    }

    function withdrawETH() public onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
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

    // // Function to update L1OFTToken address
    // function updateL1OFTToken(address _newL1OFTToken) external onlyOwner {
    //     zeroAdressCheck(_newL1OFTToken);
    //     L1OFTToken = _newL1OFTToken;
    //     emit L1OFTTokenUpdated(_newL1OFTToken);
    // }

    // Function to update threshold
    function updateThreshold(uint256 _newThreshold) external onlyOwner {
        bool isZero = isZeroValue(_newThreshold);
        require(!isZero, "zero value passed");
        threshold = _newThreshold;
        emit ThresholdUpdated(_newThreshold);
    }

    function updateAddressTo(address _addressTo) external onlyOwner {
        zeroAdressCheck(_addressTo);
        addressTo = _addressTo;
    }

    function zeroAdressCheck(address _address) private pure {
        assembly {
            if iszero(_address) {
                // revert with custom error
                mstore(0x00, 0x8aca9d85)
                revert(0x00, 0x04)
            }
        }
    }

    // Function to check if a given value is zero
    function isZeroValue(uint256 value) internal pure returns (bool) {
        return value == 0;
    }
}
