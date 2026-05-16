// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Adapter8004} from "../src/Adapter8004.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Safe-owned UUPS upgrade flow for `Adapter8004`.
///
/// The production proxies on Ethereum, Base, and Sepolia are owned by a Gnosis Safe
/// (see `deployments/2026-05-15-ownership-transfer-to-safe-report.md`), so the deployer
/// EOA can no longer call `upgradeToAndCall` directly. This script therefore performs
/// ONLY the EOA-side step: it deploys the new implementation contract. It deliberately
/// does NOT call `upgradeToAndCall`.
///
/// After the broadcast, the script prints the exact transaction the Safe signers must
/// submit through the Safe Transaction Builder:
///   - `to`    = the proxy address (`ADAPTER_PROXY_ADDRESS`)
///   - `value` = 0
///   - `data`  = `upgradeToAndCall(newImplementation, "")`
///
/// Initializer bytes are empty: the delegate.xyz upgrade adds only `constant`s
/// (`DELEGATE_REGISTRY`, `DELEGATE_RIGHTS`) and view logic — no new storage and no
/// `reinitializer`, so the proxy needs no post-upgrade initialization call.
contract DeployAdapterImplementationScript is Script {
    function run() external returns (address proxy, address implementation, bytes memory upgradeCalldata) {
        proxy = vm.envAddress("ADAPTER_PROXY_ADDRESS");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // 1. EOA-side step: deploy ONLY the new implementation. No upgrade call here.
        vm.startBroadcast(deployerKey);
        implementation = address(new Adapter8004());
        vm.stopBroadcast();

        // 2. Build the calldata the Safe must execute against the proxy. Empty initializer
        //    bytes — the delegate.xyz change is constants/logic only, no storage migration.
        upgradeCalldata = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (implementation, bytes("")));

        // 3. Print the Safe Transaction Builder parameters for this chain.
        console2.log("=== Safe Transaction Builder parameters ===");
        console2.log("to (proxy address):");
        console2.logAddress(proxy);
        console2.log("value:");
        console2.logUint(0);
        console2.log("new implementation (just deployed):");
        console2.logAddress(implementation);
        console2.log("data (upgradeToAndCall(newImplementation, 0x)):");
        console2.logBytes(upgradeCalldata);
    }
}
