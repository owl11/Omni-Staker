// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../../contracts/L1StakerSolo.sol";

contract L1StakerScript is Script {
    L1StakerSolo l1staker;
    address public susde = 0x1B6877c6Dac4b6De4c5817925DC40E2BfdAFc01b;
    address public usde = 0xf805ce4F96e0EdD6f0b6cd4be22B34b92373d696;
    uint256 _tokensToSend = 20 ether;
    address endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address oApp = 0x162cc96D5E528F3E5Ce02EF3847216a917ba55bb;
    address oApp_2 = 0xb881F50b83ca2D83cE43327D41DEe42Ab8Efe8dC;
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
        vm.startBroadcast(privateKey);
        uint256 nonce;

        address L2deployerAddr = vm.computeCreateAddress(deployer, nonce + 186);
        l1staker = new L1StakerSolo(usde, susde, endpoint, oApp, oApp_2, L2deployerAddr);
        // Stop broadcasting
        vm.stopBroadcast();
    }
}
