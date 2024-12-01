// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../../contracts/L2StakerSolo.sol";

contract makeSusde is Script {
    L2StakerSolo l2staker;
    uint256 _tokensToSend = 30 ether;
    address endpoint = 0x6Ac7bdc07A0583A362F1497252872AE6c0A5F5B8;
    address l2oApp = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE;
    address l2oApp_2 = 0x80f9Ec4bA5746d8214b3A9a73cc4390AB0F0E633;
    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function run() public {
        // Fetch the private key from environment variable
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        address L1deployerAddr = vm.computeCreateAddress(deployer, 2354 + 1);

        vm.startBroadcast(privateKey);
        l2staker = new L2StakerSolo(l2oApp, l2oApp_2, L1deployerAddr, endpoint);
        // Stop broadcasting
        vm.stopBroadcast();
    }
}
