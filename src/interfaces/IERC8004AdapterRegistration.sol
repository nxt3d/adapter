// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERCAgentBindings} from "./IERCAgentBindings.sol";
import {IERC8004IdentityRegistry} from "./IERC8004IdentityRegistry.sol";

/// @notice Agent creation entry point for `Adapter8004`: registers through an ERC-8004 registry
/// after proving control of an external bound token. Differs from `IERC8004IdentityRegistry.register`,
/// which mints an identity directly from URI + metadata only.
interface IERC8004AdapterRegistration {
    function register(
        IERCAgentBindings.TokenStandard standard,
        address tokenContract,
        uint256 tokenId,
        string calldata agentURI,
        IERC8004IdentityRegistry.MetadataEntry[] memory metadata
    ) external returns (uint256 agentId);

    /// @notice Convenience overload equivalent to `register(...)` with an empty metadata array.
    function register(
        IERCAgentBindings.TokenStandard standard,
        address tokenContract,
        uint256 tokenId,
        string calldata agentURI
    ) external returns (uint256 agentId);
}
