/**
 * @title L1StakerSolo Contract
 * @dev This contract handles staking  USDe tokens in response to LayerZero's Omnichain Fungible Token (OFT) messages.
 * It interacts with LayerZero's OFT standard to perform cross-chain token swaps and staking actions.
 * @notice The contract is designed to interact with LayerZero's Omnichain Fungible Token (OFT) Standard,
 * allowing it to respond to cross-chain OFT mint events with a token swap action.
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam, IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";

error InvalidEndpoint();
error CooldownActive();
error InsufficientBalance();
error InvalidSender();

contract OmniStakerL1 is IOAppComposer, Ownable {
    using OptionsBuilder for bytes;

    IERC20 public erc20;
    address public sErc20;
    address public addressTo;
    IOFT public IOFTerc20;
    IOFT public IOFTsErc20;
    uint128 constant LZ_TOKEN_TRANSFER_COST = 65000;

    address public immutable localEndpoint;
    bytes32 private receiverAddressInBytes32;

    event SoloStake(address receiver, uint256 amount);
    event BatchStake(uint256 batchId, uint256 amount);

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
        erc20 = IERC20(_erc20);
        sErc20 = _sErc20;
        localEndpoint = _endpoint;
        IOFTerc20 = IOFT(_iofterc20);
        IOFTsErc20 = IOFT(_ioftSerc20);
        addressTo = _addressTo;
        receiverAddressInBytes32 = OFTComposeMsgCodec.addressToBytes32(_addressTo);

        // we batch approve all the contracts that will potentially need alloewnce
        // erc20(usde) to erc4626 (serc20/susd) for staking
        erc20.approve(address(sErc20), type(uint256).max);
        // erc20 (usde) to its local OFT Adapter
        erc20.approve(address(IOFTerc20), type(uint256).max);
        // serc20 (susde) to its local OFT Adapter
        IERC20(sErc20).approve(address(IOFTsErc20), type(uint256).max);
    }

    // Internal functions
    function _createSendParamBatch(
        bytes32 _receiverInBytes,
        uint256 amount,
        bytes memory options,
        uint32 srcEid,
        bytes memory message
    ) internal pure returns (SendParam memory) {
        return SendParam(srcEid, _receiverInBytes, amount, amount * 9 / 10, options, message, "");
    }

    function _createSendParamSolo(bytes32 _receiverInBytes, uint256 amount, bytes memory options, uint32 srcEid)
        internal
        pure
        returns (SendParam memory)
    {
        return SendParam(srcEid, _receiverInBytes, amount, amount * 9 / 10, options, "", "");
    }

    function _handleStakingBatch(uint32 _srcEID, uint256 _amountLD, uint256 batchId) internal {
        uint256 shares = IERC4626(sErc20).deposit(_amountLD, address(this));
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_TOKEN_TRANSFER_COST, 0)
            .addExecutorLzComposeOption(0, 100000, uint128(gasleft()));
        bytes memory _encodedMessage = abi.encode(batchId, address(this));
        SendParam memory sendParam =
            _createSendParamBatch(receiverAddressInBytes32, shares, options, _srcEID, _encodedMessage);
        IOFT(IOFTsErc20).send{value: msg.value}(sendParam, MessagingFee(msg.value, 0), owner());
        emit BatchStake(batchId, _amountLD);
    }

    function _handleStakingSolo(uint32 _srcEID, address _receiver, bytes32 _receiverInBytes, uint256 _amountLD)
        internal
    {
        uint256 shares = IERC4626(sErc20).deposit(_amountLD, address(this));
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_TOKEN_TRANSFER_COST, 0);
        SendParam memory sendParam = _createSendParamSolo(_receiverInBytes, shares, options, _srcEID);
        IOFT(IOFTsErc20).send{value: msg.value}(sendParam, MessagingFee(msg.value, 0), _receiver);
        emit SoloStake(_receiver, _amountLD);
    }

    function lzCompose(
        address _oApp,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*Executor*/
        bytes calldata /*Executor Data*/
    ) external payable override {
        if (msg.sender != localEndpoint) revert InvalidEndpoint();
        (uint256 id, address sender) = abi.decode(OFTComposeMsgCodec.composeMsg(_message), (uint256, address));
        bytes32 _senderBytes32 = OFTComposeMsgCodec.addressToBytes32(sender);
        uint256 _amountLD = OFTComposeMsgCodec.amountLD(_message);
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);

        if (_oApp == address(IOFTerc20)) {
            if (id > 0) {
                if (_senderBytes32 != receiverAddressInBytes32) {
                    revert InvalidSender();
                }
                // batched stake, we send tokens to the contract on L2
                _handleStakingBatch(srcEid, _amountLD, id);
            } else {
                // solo stake, we send tokens to the user on L2
                // _receiverInBytes = OFTComposeMsgCodec.addressToBytes32(_receiver);
                _handleStakingSolo(srcEid, sender, _senderBytes32, _amountLD);
            }
        } else {
            revert InvalidEndpoint();
        }
    }

    function updateAddressTo(address _addressTo) external onlyOwner {
        zeroAddressCheck(_addressTo);
        receiverAddressInBytes32 = OFTComposeMsgCodec.addressToBytes32(_addressTo);
        addressTo = _addressTo;
    }

    function withdrawETH() public onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    function rescueToken(address _token, uint256 amount) public onlyOwner {
        IERC20 token = IERC20(_token);
        bool success = token.transfer(msg.sender, amount);
        require(success);
    }

    function zeroAddressCheck(address _address) private pure {
        assembly {
            if iszero(_address) {
                // revert with custom error
                mstore(0x00, 0x8aca9d85)
                revert(0x00, 0x04)
            }
        }
    }
}
