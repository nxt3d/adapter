// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Adapter8004} from "../src/Adapter8004.sol";

contract TransferAdapterOwnershipScript is Script {
    function run() external returns (address proxy, address previousOwner, address newOwner) {
        proxy = vm.envAddress("ADAPTER_PROXY_ADDRESS");
        newOwner = vm.envAddress("ADAPTER_NEW_OWNER");
        uint256 ownerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        Adapter8004 adapter = Adapter8004(payable(proxy));
        previousOwner = adapter.owner();

        vm.startBroadcast(ownerKey);
        adapter.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
