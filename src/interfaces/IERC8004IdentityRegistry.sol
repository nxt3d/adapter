// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC8004IdentityRecord} from "./IERC8004IdentityRecord.sol";

interface IERC8004IdentityRegistry is IERC8004IdentityRecord {
    struct MetadataEntry {
        string metadataKey;
        bytes metadataValue;
    }

    function register(string memory agentURI, MetadataEntry[] memory metadata) external returns (uint256 agentId);

    function register(string memory agentURI) external returns (uint256 agentId);

    function register() external returns (uint256 agentId);
}
