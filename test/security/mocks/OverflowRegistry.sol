// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC8004IdentityRegistry} from "../../../src/interfaces/IERC8004IdentityRegistry.sol";

/// @notice Stub registry that hands out `type(uint256).max` as the next agentId
/// so tests can observe what happens when the adapter's `agentId + 1`
/// encoding overflows.
contract OverflowRegistry is IERC8004IdentityRegistry {
    function register(string memory, MetadataEntry[] memory) external pure returns (uint256) {
        return type(uint256).max;
    }

    function register(string memory) external pure returns (uint256) {
        return type(uint256).max;
    }

    function register() external pure returns (uint256) {
        return type(uint256).max;
    }

    function setMetadata(uint256, string memory, bytes memory) external {}
    function setAgentURI(uint256, string calldata) external {}
    function setAgentWallet(uint256, address, uint256, bytes calldata) external {}
    function unsetAgentWallet(uint256) external {}

    function getMetadata(uint256, string memory) external pure returns (bytes memory) {
        return "";
    }

    function getAgentWallet(uint256) external pure returns (address) {
        return address(0);
    }

    function ownerOf(uint256) external pure returns (address) {
        return address(0);
    }

    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}
