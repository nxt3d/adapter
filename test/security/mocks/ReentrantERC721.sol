// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice ERC-721 mock that on `ownerOf` triggers a configured reentry call
/// AND propagates the inner failure verbatim. Used to prove the adapter's
/// `nonReentrant` modifier short-circuits with `ReentrancyGuardReentrantCall`
/// when a malicious token tries to reenter a state-mutating adapter function.
contract ReentrantERC721 {
    mapping(uint256 => address) public forcedOwner;
    address public reenterTarget;
    bytes public reenterData;
    bool public reenterArmed;

    function setOwner(uint256 tokenId, address owner) external {
        forcedOwner[tokenId] = owner;
    }

    function setReentry(address target, bytes calldata data) external {
        reenterTarget = target;
        reenterData = data;
        reenterArmed = true;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        if (reenterArmed) {
            // Note: Solidity emits STATICCALL when calling this through `IERC721.ownerOf`
            // (declared `view`). The reentry CALL below stays inside that static frame, so the
            // mock CANNOT SSTORE to disarm. We rely on the adapter's `nonReentrant` guard
            // (which fires on the SLOAD-based entry check) to short-circuit the inner frame
            // before infinite recursion can happen — the inner call reverts with
            // `ReentrancyGuardReentrantCall()` and the assembly below propagates that selector.
            (bool ok, bytes memory ret) = reenterTarget.staticcall(reenterData);
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        return forcedOwner[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }
}
