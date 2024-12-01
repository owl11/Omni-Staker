// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam, IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SwapMock Contract
/// @dev This contract mocks an ERC20 token swap in response to an OFT being received (lzReceive) on the destination chain.
/// @notice The contract is designed to interact with LayerZero's Omnichain Fungible Token (OFT) Standard,
/// allowing it to respond to cross-chain OFT mint events with a token swap action.
contract L1Staker is IOAppComposer, Ownable {
    using OptionsBuilder for bytes;

    IERC20 public erc20;
    address public sErc20;
    address public addressTo;

    IOFT public IOFTerc20;
    IOFT public IOFTsErc20;

    address public immutable endpoint;
    bytes32 private receiverAddressInBytes32;

    /// @notice Emitted when a token swap is executed.
    /// @param user The address of the user who receives the swapped tokens.
    /// @param tokenOut The address of the ERC20 token being swapped.
    /// @param amount The amount of tokens swapped.
    event Swapped(address indexed user, address tokenOut, uint256 amount);
    event msgRecieved(address Executor, bytes Executor_Data);

    /// @notice Constructs the SwapMock contract.
    /// @dev Initializes the contract.
    /// @param _erc20 The address of the ERC20 token that will be used in swaps.
    /// @param _endpoint LayerZero Endpoint address
    constructor(
        address _erc20,
        address _sErc20,
        address _endpoint,
        address _iofterc20,
        address _ioftSerc20,
        address _addressTo
    ) Ownable(msg.sender) {
        addressTo = _addressTo;
        receiverAddressInBytes32 = OFTComposeMsgCodec.addressToBytes32(addressTo);

        erc20 = IERC20(_erc20);
        sErc20 = _sErc20;
        endpoint = _endpoint;
        IOFTerc20 = IOFT(_iofterc20);
        IOFTsErc20 = IOFT(_ioftSerc20);
        // we batch approve all the contracts that will potentially need alloewnce
        // erc20(usde) to erc4626 (serc20/susd) for staking
        erc20.approve(address(sErc20), type(uint256).max);
        // serc20 (susde) to its self, for unstaking
        IERC20(sErc20).approve(sErc20, type(uint256).max);

        // erc20 (usde) to its local OFT Adapter
        erc20.approve(address(IOFTerc20), type(uint256).max);
        // serc20 (susde) to its local OFT Adapter
        IERC20(sErc20).approve(address(IOFTsErc20), type(uint256).max);
    }

    /// @notice Handles incoming composed messages from LayerZero.
    /// @dev Decodes the message payload to perform a token swap.
    ///      This method expects the encoded compose message to contain the swap amount and recipient address.
    /// @param _oApp The address of the originating OApp.
    /// @param /*_guid*/ The globally unique identifier of the message (unused in this mock).
    /// @param _message The encoded message content in the format of the OFTComposeMsgCodec.
    /// @param /*Executor*/ Executor address (unused in this mock).
    /// @param /*Executor Data*/ Additional data for checking for a specific executor (unused in this mock).
    function lzCompose(
        address _oApp,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*Executor*/
        bytes calldata /*Executor Data*/
    ) external payable override {
        require(_oApp == address(IOFTerc20), "!oApp");
        require(msg.sender == endpoint, "!endpoint");
        // Extract the composed message from the delivered message using the MsgCodec
        bytes32 _receiver = OFTComposeMsgCodec.composeFrom(_message);
        uint256 _amountLD = OFTComposeMsgCodec.amountLD(_message);
        // Execute the token swap by transferring the specified amount to the receiver
        uint256 shares = IERC4626(sErc20).deposit(_amountLD, address(this));
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0)
            .addExecutorLzComposeOption(0, 80000, 0.003 ether);

        SendParam memory sendParam =
            SendParam(40330, _receiver, shares, shares * 9 / 10, options, OFTComposeMsgCodec.composeMsg(_message), "");
        IOFT(IOFTsErc20).send{value: msg.value}(
            sendParam, MessagingFee(msg.value, 0), OFTComposeMsgCodec.bytes32ToAddress(_receiver)
        );
        // Emit an event to log the token swap details
        // emit Swapped(_receiver, address(erc20), _amountLD);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
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
}
