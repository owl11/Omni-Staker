// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {Script, console} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../contracts/L1Staker.sol";

contract L1StakerScript is Script {
    using OptionsBuilder for bytes;
    // script to transfer oft tokens from l1 to l2

    address usde = 0xf805ce4F96e0EdD6f0b6cd4be22B34b92373d696;
    address susde = 0x1B6877c6Dac4b6De4c5817925DC40E2BfdAFc01b;
    address l1oApp = 0x162cc96D5E528F3E5Ce02EF3847216a917ba55bb;
    address l1oApp_2 = 0xb881F50b83ca2D83cE43327D41DEe42Ab8Efe8dC;
    uint256 _tokensToSend = 1 ether;

    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        bytes memory _encodedMessage = abi.encode(1);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);

        SendParam memory sendParam = SendParam(
            40330, // You can also make this dynamic if needed
            addressToBytes32(deployer),
            _tokensToSend,
            _tokensToSend * 9 / 10,
            _extraOptions,
            _encodedMessage,
            ""
        );
        IOFT sourceOFT = IOFT(0xb881F50b83ca2D83cE43327D41DEe42Ab8Efe8dC);

        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);
        vm.startBroadcast(privateKey);
        sourceOFT.send{value: fee.nativeFee}(sendParam, fee, deployer);
        vm.stopBroadcast();
    }
}
