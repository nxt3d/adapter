// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC8004IdentityRecord} from "../../src/interfaces/IERC8004IdentityRecord.sol";
import {IERC8004IdentityRegistry} from "../../src/interfaces/IERC8004IdentityRegistry.sol";

contract MockIdentityRegistry is ERC721URIStorage, EIP712, IERC8004IdentityRegistry {
    bytes32 private constant AGENT_WALLET_SET_TYPEHASH =
        keccak256("AgentWalletSet(uint256 agentId,address newWallet,address owner,uint256 deadline)");
    bytes32 private constant RESERVED_AGENT_WALLET_KEY_HASH = keccak256("agentWallet");
    bytes4 private constant ERC1271_MAGICVALUE = 0x1626ba7e;
    uint256 private constant MAX_DEADLINE_DELAY = 5 minutes;

    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    event MetadataSet(
        uint256 indexed agentId, string indexed indexedMetadataKey, string metadataKey, bytes metadataValue
    );
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);

    uint256 private _lastId;
    mapping(uint256 agentId => mapping(string metadataKey => bytes metadataValue)) private _metadata;

    constructor() ERC721("AgentIdentity", "AGENT") EIP712("ERC8004IdentityRegistry", "1") {}

    function register(string memory agentURI, MetadataEntry[] memory metadata)
        public
        override
        returns (uint256 agentId)
    {
        agentId = _lastId++;
        _metadata[agentId]["agentWallet"] = abi.encodePacked(msg.sender);
        _safeMint(msg.sender, agentId);

        if (bytes(agentURI).length != 0) {
            _setTokenURI(agentId, agentURI);
        }

        emit Registered(agentId, agentURI, msg.sender);
        emit MetadataSet(agentId, "agentWallet", "agentWallet", abi.encodePacked(msg.sender));

        uint256 length = metadata.length;
        for (uint256 i; i < length; ++i) {
            if (keccak256(bytes(metadata[i].metadataKey)) == RESERVED_AGENT_WALLET_KEY_HASH) {
                revert("reserved key");
            }
            _metadata[agentId][metadata[i].metadataKey] = metadata[i].metadataValue;
            emit MetadataSet(agentId, metadata[i].metadataKey, metadata[i].metadataKey, metadata[i].metadataValue);
        }
    }

    function register(string memory agentURI) external override returns (uint256 agentId) {
        return register(agentURI, new MetadataEntry[](0));
    }

    function register() external override returns (uint256 agentId) {
        return register("", new MetadataEntry[](0));
    }

    function getMetadata(uint256 agentId, string memory metadataKey) external view override returns (bytes memory) {
        return _metadata[agentId][metadataKey];
    }

    function ownerOf(uint256 agentId) public view override(ERC721, IERC721, IERC8004IdentityRecord) returns (address) {
        return super.ownerOf(agentId);
    }

    function tokenURI(uint256 agentId)
        public
        view
        override(ERC721URIStorage, IERC8004IdentityRecord)
        returns (string memory)
    {
        return super.tokenURI(agentId);
    }

    function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) external override {
        _requireAuthorized(agentId);
        if (keccak256(bytes(metadataKey)) == RESERVED_AGENT_WALLET_KEY_HASH) {
            revert("reserved key");
        }
        _metadata[agentId][metadataKey] = metadataValue;
        emit MetadataSet(agentId, metadataKey, metadataKey, metadataValue);
    }

    function setAgentURI(uint256 agentId, string calldata newURI) external override {
        _requireAuthorized(agentId);
        _setTokenURI(agentId, newURI);
        emit URIUpdated(agentId, newURI, msg.sender);
    }

    function getAgentWallet(uint256 agentId) external view override returns (address) {
        bytes memory walletData = _metadata[agentId]["agentWallet"];
        if (walletData.length < 20) {
            return address(0);
        }
        return address(bytes20(walletData));
    }

    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata signature)
        external
        override
    {
        _requireAuthorized(agentId);
        require(newWallet != address(0), "bad wallet");
        require(block.timestamp <= deadline, "expired");
        require(deadline <= block.timestamp + MAX_DEADLINE_DELAY, "deadline too far");

        address owner = ownerOf(agentId);
        bytes32 structHash = keccak256(abi.encode(AGENT_WALLET_SET_TYPEHASH, agentId, newWallet, owner, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);

        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, signature);
        if (err != ECDSA.RecoverError.NoError || recovered != newWallet) {
            (bool ok, bytes memory res) =
                newWallet.staticcall(abi.encodeCall(IERC1271.isValidSignature, (digest, signature)));
            require(ok && res.length >= 32 && abi.decode(res, (bytes4)) == ERC1271_MAGICVALUE, "invalid wallet sig");
        }

        _metadata[agentId]["agentWallet"] = abi.encodePacked(newWallet);
        emit MetadataSet(agentId, "agentWallet", "agentWallet", abi.encodePacked(newWallet));
    }

    function unsetAgentWallet(uint256 agentId) external override {
        _requireAuthorized(agentId);
        _metadata[agentId]["agentWallet"] = "";
        emit MetadataSet(agentId, "agentWallet", "agentWallet", "");
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            _metadata[tokenId]["agentWallet"] = "";
            emit MetadataSet(tokenId, "agentWallet", "agentWallet", "");
        }
        return super._update(to, tokenId, auth);
    }

    function _requireAuthorized(uint256 agentId) internal view {
        address owner = ownerOf(agentId);
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender) || msg.sender == getApproved(agentId),
            "Not authorized"
        );
    }
}
