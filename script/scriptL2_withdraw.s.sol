// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {Script, console} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../contracts/L2Staker.sol";

contract StakerL2_withdrawl is Script {
    using OptionsBuilder for bytes;

    address l2staker = 0x01f46253bC7011990AB1D8e8D996ED9700ee2Ae0;
    address l2oApp = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE;
    address l2oApp_2 = 0x80f9Ec4bA5746d8214b3A9a73cc4390AB0F0E633;
    uint256 _tokensToSend = 5 ether;

    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function run() public {
        L2Staker staker = L2Staker(l2staker);
        uint256 privateKey;
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        staker.withdraw(1);
        vm.stopBroadcast();

        privateKey = vm.envUint("PRIVATE_KEY_2");
        vm.startBroadcast(privateKey);
        staker.withdraw(1);

        vm.stopBroadcast();
    }
}
