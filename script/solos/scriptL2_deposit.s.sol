// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {Script, console} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../../contracts/L2StakerSolo.sol";

contract L1StakerScript is Script {
    using OptionsBuilder for bytes;

    address l2staker = 0xe92f50d273C418e48A2A1C1d88B8E17CF8Be001b;
    address l2oApp = 0x426E7d03f9803Dd11cb8616C65b99a3c0AfeA6dE;
    address l2oApp_2 = 0x80f9Ec4bA5746d8214b3A9a73cc4390AB0F0E633;
    uint256 _tokensToSend = 3 ether;

    struct Batch {
        uint256 startUnix;
        uint256 amountTotal;
        uint256 endUnix;
        uint256 totalInSToken;
    }

    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function run() public {
        L2StakerSolo staker = L2StakerSolo(l2staker);
        uint256 privateKey;
        MessagingFee memory fee = staker.estimateLZFee(_tokensToSend, IOFT(l2oApp));

        privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        console.log(IERC20(l2oApp).balanceOf(deployer));
        vm.startBroadcast(privateKey);
        IERC20(l2oApp).approve(address(staker), type(uint256).max);
        // IERC20(l2oApp_2).approve(address(staker), type(uint256).max);
        staker.depositUSDERecieveSUSD{value: fee.nativeFee}(_tokensToSend, fee);
        // staker.updateAddressTo();
        vm.stopBroadcast();
        console.log(IERC20(l2oApp).balanceOf(deployer));
    }
}
