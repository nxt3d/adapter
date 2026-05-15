// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERCAgentBindings} from "./IERCAgentBindings.sol";
import {IERC8004IdentityRegistry} from "./IERC8004IdentityRegistry.sol";

/// @notice Event-only surface for the counterfactual register family on `Adapter8004`. The functions
/// themselves stay on the adapter (they need internal helpers); this interface owns the event
/// declarations so off-chain consumers and tests can depend on a stable type without importing
/// the full contract.
interface IERC8004AdapterCounterfactual {
    /// @notice Off-chain (counterfactual) registration claim. No registry write, no SSTORE.
    /// Indexers MUST treat the latest event per (tokenContract, tokenId) as authoritative.
    event CounterfactualAgentRegistered(
        bytes32 indexed registrationHash,
        address indexed tokenContract,
        uint256 indexed tokenId,
        IERCAgentBindings.TokenStandard standard,
        string agentURI,
        IERC8004IdentityRegistry.MetadataEntry[] metadata,
        address emitter
    );

    /// @notice Off-chain agent URI update for a counterfactual identity. No registry write, no SSTORE.
    event CounterfactualAgentURISet(
        bytes32 indexed registrationHash,
        address indexed tokenContract,
        uint256 indexed tokenId,
        string newURI,
        address emitter
    );

    /// @notice Off-chain metadata write for a counterfactual identity. No registry write, no SSTORE.
    event CounterfactualMetadataSet(
        bytes32 indexed registrationHash,
        address indexed tokenContract,
        uint256 indexed tokenId,
        string metadataKey,
        bytes metadataValue,
        address emitter
    );

    /// @notice Off-chain batch metadata write for a counterfactual identity. No registry write, no SSTORE.
    event CounterfactualMetadataBatchSet(
        bytes32 indexed registrationHash,
        address indexed tokenContract,
        uint256 indexed tokenId,
        IERC8004IdentityRegistry.MetadataEntry[] metadata,
        address emitter
    );

    /// @notice Off-chain agent wallet assignment for a counterfactual identity. No signature, no registry write.
    event CounterfactualAgentWalletSet(
        bytes32 indexed registrationHash,
        address indexed tokenContract,
        uint256 indexed tokenId,
        address newWallet,
        address emitter
    );

    /// @notice Off-chain agent wallet clear for a counterfactual identity. No registry write, no SSTORE.
    event CounterfactualAgentWalletUnset(
        bytes32 indexed registrationHash, address indexed tokenContract, uint256 indexed tokenId, address emitter
    );
}
