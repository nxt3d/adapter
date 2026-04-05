// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC8004IdentityRegistry {
    struct MetadataEntry {
        string metadataKey;
        bytes metadataValue;
    }

    function register(string memory agentURI, MetadataEntry[] memory metadata) external returns (uint256 agentId);

    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) external;

    function setAgentURI(uint256 agentId, string calldata newURI) external;

    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata signature) external;

    function unsetAgentWallet(uint256 agentId) external;

    function getMetadata(uint256 agentId, string memory metadataKey) external view returns (bytes memory);

    function getAgentWallet(uint256 agentId) external view returns (address);

    function ownerOf(uint256 agentId) external view returns (address);

    function tokenURI(uint256 agentId) external view returns (string memory);
}
