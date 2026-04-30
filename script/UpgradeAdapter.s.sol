// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Adapter8004} from "../src/Adapter8004.sol";

contract UpgradeAdapterScript is Script {
    function run() external returns (address proxy, address implementation) {
        proxy = vm.envAddress("ADAPTER_PROXY_ADDRESS");
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");

        vm.startBroadcast(ownerKey);

        implementation = address(new Adapter8004());
        Adapter8004(payable(proxy)).upgradeToAndCall(implementation, bytes(""));

        vm.stopBroadcast();
    }
}
