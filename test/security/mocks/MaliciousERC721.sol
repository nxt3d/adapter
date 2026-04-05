// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice Hostile ERC-721 used to probe the adapter's trust boundary.
/// The contract lets tests configure per-token `ownerOf` results and
/// optionally perform a reentrant call into an arbitrary target from
/// inside the supposedly read-only `ownerOf` function.
contract MaliciousERC721 {
    mapping(uint256 => address) public forcedOwner;
    bool public shouldRevert;
    bool public reenterOnOwnerOf;
    address public reenterTarget;
    bytes public reenterData;
    uint256 public reenterCount;
    uint256 public reenterCallLimit = 1;

    error Unowned();

    function setOwner(uint256 tokenId, address owner) external {
        forcedOwner[tokenId] = owner;
    }

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function setReentry(address target, bytes calldata data) external {
        reenterOnOwnerOf = true;
        reenterTarget = target;
        reenterData = data;
    }

    function clearReentry() external {
        reenterOnOwnerOf = false;
        reenterTarget = address(0);
        delete reenterData;
    }

    function setReenterCallLimit(uint256 limit) external {
        reenterCallLimit = limit;
    }

    function ownerOf(uint256 tokenId) external returns (address) {
        if (shouldRevert) revert Unowned();

        if (reenterOnOwnerOf && reenterCount < reenterCallLimit) {
            reenterCount += 1;
            (bool ok,) = reenterTarget.call(reenterData);
            // Swallow failure so tests can observe the adapter state,
            // not the reentry outcome.
            ok;
        }

        address owner = forcedOwner[tokenId];
        if (owner == address(0)) revert Unowned();
        return owner;
    }

    // Satisfy interface for discovery purposes; unused by the adapter.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }
}
