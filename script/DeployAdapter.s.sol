// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Adapter8004} from "../src/Adapter8004.sol";

contract DeployAdapterScript is Script {
    function run() external returns (Adapter8004 adapter) {
        // 1. Load the target ERC-8004 registry the adapter will forward into.
        address identityRegistry = vm.envAddress("IDENTITY_REGISTRY_ADDRESS");

        // 2. Load the deployer private key. The deployer becomes the admin.
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // 3. Start the deployment broadcast as the deployer.
        vm.startBroadcast(deployerKey);

        // 4. Deploy the adapter implementation contract.
        Adapter8004 implementation = new Adapter8004();

        // 5. Deploy the proxy and initialize it with the registry and deployer-as-admin.
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(Adapter8004.initialize, (identityRegistry, deployer))
        );

        // 6. Return the proxy address typed as the adapter interface.
        adapter = Adapter8004(address(proxy));

        // 7. Stop the deployment broadcast.
        vm.stopBroadcast();
    }
}
