// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {JustArray} from "../src/JustArray.sol";


contract MyTokenScript is Script {

    JustArray public contractNeedToDeploy;

    function setUp() public {}

    function run() public {

        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast();
        contractNeedToDeploy = new JustArray(

        );
        console.log("MyToken deployed to:", address(contractNeedToDeploy));

        vm.stopBroadcast();
    }
}

