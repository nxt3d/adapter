// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/ERC6909.sol";

contract MockERC6909 is ERC6909 {
    function mint(address to, uint256 tokenId, uint256 amount) external {
        _mint(to, tokenId, amount);
    }
}
