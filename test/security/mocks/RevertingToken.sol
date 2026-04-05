// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Token contract whose every read path reverts. Used to verify
/// the adapter cannot be coerced into accepting a binding when the
/// target contract behaves pathologically.
contract RevertingToken {
    error AlwaysReverts();

    function ownerOf(uint256) external pure returns (address) {
        revert AlwaysReverts();
    }

    function balanceOf(address, uint256) external pure returns (uint256) {
        revert AlwaysReverts();
    }
}
