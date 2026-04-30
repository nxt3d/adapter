// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC6909} from "@openzeppelin/contracts/interfaces/IERC6909.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERCAgentBindings} from "./interfaces/IERCAgentBindings.sol";
import {IERC8004IdentityRegistry} from "./interfaces/IERC8004IdentityRegistry.sol";

contract Adapter8004 is Initializable, OwnableUpgradeable, UUPSUpgradeable, IERC721Receiver, IERCAgentBindings {
    string public constant BINDING_METADATA_KEY = "agent-binding";
    bytes32 private constant BINDING_METADATA_KEY_HASH = keccak256(bytes(BINDING_METADATA_KEY));

    error InvalidTokenContract();
    error ReservedMetadataKey(string metadataKey);
    error NotController(address account, uint256 agentId);
    error UnknownAgent(uint256 agentId);

    event AgentBound(
        uint256 indexed agentId,
        TokenStandard indexed standard,
        address indexed tokenContract,
        uint256 tokenId,
        address registeredBy
    );

    event MetadataBatchSet(uint256 indexed agentId, uint256 count, address indexed updatedBy);
    event IdentityRegistryUpdated(
        address indexed previousRegistry, address indexed newRegistry, address indexed updatedBy
    );

    IERC8004IdentityRegistry public identityRegistry;

    mapping(uint256 agentId => Binding binding) private _bindings;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address identityRegistry_, address initialOwner) external initializer {
        // 1. Reject an unusable registry target before any state is initialized.
        if (identityRegistry_ == address(0)) {
            revert InvalidTokenContract();
        }

        // 2. Set the adapter admin who controls upgrades and registry repointing.
        __Ownable_init(initialOwner);

        // 3. Store the initial ERC-8004 registry the adapter will forward into.
        identityRegistry = IERC8004IdentityRegistry(identityRegistry_);
    }

    function setIdentityRegistry(address newIdentityRegistry) external onlyOwner {
        // 1. Reject an unusable registry target.
        if (newIdentityRegistry == address(0)) {
            revert InvalidTokenContract();
        }

        // 2. Capture the previous address for upgrade/migration observability.
        address previousRegistry = address(identityRegistry);

        // 3. Repoint future adapter calls to the new ERC-8004 registry.
        identityRegistry = IERC8004IdentityRegistry(newIdentityRegistry);

        // 4. Emit the registry change so indexers and operators can track migrations.
        emit IdentityRegistryUpdated(previousRegistry, newIdentityRegistry, msg.sender);
    }

    function register(
        TokenStandard standard,
        address tokenContract,
        uint256 tokenId,
        string calldata agentURI,
        IERC8004IdentityRegistry.MetadataEntry[] calldata metadata
    ) external returns (uint256 agentId) {
        // 1. Reject an unusable external token contract address.
        if (tokenContract == address(0)) {
            revert InvalidTokenContract();
        }

        // 2. Confirm the caller currently controls the token being bound.
        _requireBindingControl(standard, tokenContract, tokenId, msg.sender);

        // 3. Reject user-supplied metadata entries that try to override the canonical binding record.
        _requireNoReservedBindingKey(metadata);

        // 4. Register the ERC-8004 identity so the adapter becomes the registry owner.
        agentId = identityRegistry.register(agentURI, metadata);

        // 5. Persist the immutable link from the ERC-8004 agent to the external token.
        _bindings[agentId] = Binding({standard: standard, tokenContract: tokenContract, tokenId: tokenId});

        // 6. Write the canonical binding metadata (binding contract address only; ERC-8217).
        identityRegistry.setMetadata(agentId, BINDING_METADATA_KEY, abi.encodePacked(address(this)));

        // 7. Clear the default ERC-8004 wallet because registration set it to the adapter.
        identityRegistry.unsetAgentWallet(agentId);

        // 8. Emit the final binding record for off-chain discovery.
        emit AgentBound(agentId, standard, tokenContract, tokenId, msg.sender);
    }

    function setAgentURI(uint256 agentId, string calldata newURI) external {
        // 1. Confirm the caller currently controls the bound token.
        _requireController(agentId, msg.sender);

        // 2. Forward the URI update into the ERC-8004 registry.
        identityRegistry.setAgentURI(agentId, newURI);
    }

    function setMetadata(uint256 agentId, string calldata metadataKey, bytes calldata metadataValue) external {
        // 1. Confirm the caller currently controls the bound token.
        _requireController(agentId, msg.sender);

        // 2. Prevent callers from overwriting the canonical binding metadata.
        if (keccak256(bytes(metadataKey)) == BINDING_METADATA_KEY_HASH) {
            revert ReservedMetadataKey(metadataKey);
        }

        // 3. Forward the metadata write into the ERC-8004 registry.
        identityRegistry.setMetadata(agentId, metadataKey, metadataValue);
    }

    function setMetadataBatch(uint256 agentId, IERC8004IdentityRegistry.MetadataEntry[] calldata metadata) external {
        // 1. Confirm the caller currently controls the bound token.
        _requireController(agentId, msg.sender);

        // 2. Prevent callers from overwriting the canonical binding metadata.
        _requireNoReservedBindingKey(metadata);

        // 3. Replay each metadata write through the ERC-8004 registry one by one.
        uint256 length = metadata.length;
        for (uint256 i; i < length; ++i) {
            identityRegistry.setMetadata(agentId, metadata[i].metadataKey, metadata[i].metadataValue);
        }

        // 4. Emit one adapter-level event describing the batch operation.
        emit MetadataBatchSet(agentId, length, msg.sender);
    }

    /// @notice Owner-only migration helper to rewrite legacy `agent-binding` rows into the ERC-8217 20-byte format.
    function rewriteBindingMetadata(uint256 agentId) external onlyOwner {
        // 1. Reject unknown agents before touching registry state.
        Binding memory binding = _bindings[agentId];
        if (binding.tokenContract == address(0)) {
            revert UnknownAgent(agentId);
        }

        // 2. Rewrite the canonical metadata using the proxy address as the binding contract.
        identityRegistry.setMetadata(agentId, BINDING_METADATA_KEY, abi.encodePacked(address(this)));
    }

    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata signature) external {
        // 1. Confirm the caller currently controls the bound token.
        _requireController(agentId, msg.sender);

        // 2. Forward the wallet assignment to ERC-8004, which enforces the wallet proof.
        identityRegistry.setAgentWallet(agentId, newWallet, deadline, signature);
    }

    function unsetAgentWallet(uint256 agentId) external {
        // 1. Confirm the caller currently controls the bound token.
        _requireController(agentId, msg.sender);

        // 2. Forward the wallet clear operation to the ERC-8004 registry.
        identityRegistry.unsetAgentWallet(agentId);
    }

    function bindingOf(uint256 agentId) external view override returns (Binding memory) {
        // 1. Load the stored binding for the requested agent.
        Binding memory binding = _bindings[agentId];

        // 2. Reject unknown agents instead of returning an empty struct.
        if (binding.tokenContract == address(0)) {
            revert UnknownAgent(agentId);
        }

        // 3. Return the immutable token binding.
        return binding;
    }

    function isController(uint256 agentId, address account) external view returns (bool) {
        // 1. Load the binding that defines who controls this agent.
        Binding memory binding = _bindings[agentId];

        // 2. Unknown agents do not have a controller.
        if (binding.tokenContract == address(0)) {
            return false;
        }

        // 3. Re-evaluate control against the current bound-token ownership state.
        return _hasBindingControl(binding, account);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        // 1. Return the standard receiver selector so safe ERC-721 transfers to the adapter succeed.
        return IERC721Receiver.onERC721Received.selector;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // 1. Restrict upgrades to the adapter owner.
        // 2. Accept the implementation address through UUPS validation in the inherited logic.
        newImplementation;
    }

    function _requireController(uint256 agentId, address account) internal view {
        // 1. Load the binding for the requested agent.
        Binding memory binding = _bindings[agentId];

        // 2. Reject unknown agents before checking token ownership state.
        if (binding.tokenContract == address(0)) {
            revert UnknownAgent(agentId);
        }

        // 3. Revert when the caller no longer controls the bound token.
        if (!_hasBindingControl(binding, account)) {
            revert NotController(account, agentId);
        }
    }

    function _requireBindingControl(TokenStandard standard, address tokenContract, uint256 tokenId, address account)
        internal
        view
    {
        // 1. Reuse the token-standard-specific control check before first registration.
        if (!_hasBindingControl(standard, tokenContract, tokenId, account)) {
            revert NotController(account, type(uint256).max);
        }
    }

    function _hasBindingControl(Binding memory binding, address account) internal view returns (bool) {
        // 1. ERC-721 control means current NFT ownership.
        if (binding.standard == TokenStandard.ERC721) {
            return IERC721(binding.tokenContract).ownerOf(binding.tokenId) == account;
        }

        // 2. ERC-1155 control means any positive balance for the bound id.
        if (binding.standard == TokenStandard.ERC1155) {
            return IERC1155(binding.tokenContract).balanceOf(account, binding.tokenId) > 0;
        }

        // 3. ERC-6909 control also means any positive balance for the bound id.
        return IERC6909(binding.tokenContract).balanceOf(account, binding.tokenId) > 0;
    }

    function _hasBindingControl(TokenStandard standard, address tokenContract, uint256 tokenId, address account)
        internal
        view
        returns (bool)
    {
        // 1. ERC-721 control means current NFT ownership.
        if (standard == TokenStandard.ERC721) {
            return IERC721(tokenContract).ownerOf(tokenId) == account;
        }

        // 2. ERC-1155 control means any positive balance for the bound id.
        if (standard == TokenStandard.ERC1155) {
            return IERC1155(tokenContract).balanceOf(account, tokenId) > 0;
        }

        // 3. ERC-6909 control also means any positive balance for the bound id.
        return IERC6909(tokenContract).balanceOf(account, tokenId) > 0;
    }

    function _requireNotReservedBindingKey(string calldata metadataKey) internal pure {
        // 1. Reject writes that target the canonical binding metadata slot.
        if (keccak256(bytes(metadataKey)) == BINDING_METADATA_KEY_HASH) {
            revert ReservedMetadataKey(metadataKey);
        }
    }

    function _requireNoReservedBindingKey(IERC8004IdentityRegistry.MetadataEntry[] calldata metadata) internal pure {
        // 1. Scan user-supplied metadata and reject any entry that targets the canonical binding metadata slot.
        uint256 length = metadata.length;
        for (uint256 i; i < length; ++i) {
            if (keccak256(bytes(metadata[i].metadataKey)) == BINDING_METADATA_KEY_HASH) {
                revert ReservedMetadataKey(metadata[i].metadataKey);
            }
        }
    }
}
