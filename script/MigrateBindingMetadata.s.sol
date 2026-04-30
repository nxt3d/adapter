// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Adapter8004} from "../src/Adapter8004.sol";

contract MigrateBindingMetadataScript is Script {
    function run() external returns (uint256 rewrittenCount) {
        Adapter8004 adapter = Adapter8004(vm.envAddress("ADAPTER_PROXY_ADDRESS"));
        uint256 ownerKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256[] memory agentIds = _loadAgentIds();

        vm.startBroadcast(ownerKey);

        rewrittenCount = agentIds.length;
        for (uint256 i; i < rewrittenCount; ++i) {
            adapter.rewriteBindingMetadata(agentIds[i]);
        }

        vm.stopBroadcast();
    }

    function _loadAgentIds() internal view returns (uint256[] memory agentIds) {
        string memory filePath = vm.envOr("AGENT_IDS_FILE", string(""));
        string memory raw = bytes(filePath).length == 0 ? vm.envOr("AGENT_IDS", string("")) : vm.readFile(filePath);
        bytes memory data = bytes(raw);
        uint256 count;
        bool inNumber;

        for (uint256 i; i < data.length; ++i) {
            if (_isDigit(data[i])) {
                if (!inNumber) {
                    inNumber = true;
                    count++;
                }
            } else {
                inNumber = false;
            }
        }

        require(count != 0, "no agent ids provided");

        agentIds = new uint256[](count);
        uint256 current;
        uint256 index;
        inNumber = false;

        for (uint256 i; i < data.length; ++i) {
            bytes1 char = data[i];
            if (_isDigit(char)) {
                current = (current * 10) + (uint8(char) - 48);
                inNumber = true;
                continue;
            }

            if (inNumber) {
                agentIds[index++] = current;
                current = 0;
                inNumber = false;
            }
        }

        if (inNumber) {
            agentIds[index] = current;
        }
    }

    function _isDigit(bytes1 char) internal pure returns (bool) {
        return char >= bytes1("0") && char <= bytes1("9");
    }
}
