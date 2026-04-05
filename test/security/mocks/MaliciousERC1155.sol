// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Hostile ERC-1155 for probing the adapter's `_hasBindingControl`
/// path. Only implements `balanceOf` — the adapter never calls anything
/// else on a bound 1155 contract.
contract MaliciousERC1155 {
    mapping(uint256 => mapping(address => uint256)) public forcedBalance;
    bool public shouldRevert;
    bool public reenterOnBalanceOf;
    address public reenterTarget;
    bytes public reenterData;
    uint256 public reenterCount;
    uint256 public reenterCallLimit = 1;

    error HostileRevert();

    function setBalance(address account, uint256 id, uint256 balance) external {
        forcedBalance[id][account] = balance;
    }

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function setReentry(address target, bytes calldata data) external {
        reenterOnBalanceOf = true;
        reenterTarget = target;
        reenterData = data;
    }

    function clearReentry() external {
        reenterOnBalanceOf = false;
        reenterTarget = address(0);
        delete reenterData;
    }

    function setReenterCallLimit(uint256 limit) external {
        reenterCallLimit = limit;
    }

    function balanceOf(address account, uint256 id) external returns (uint256) {
        if (shouldRevert) revert HostileRevert();

        if (reenterOnBalanceOf && reenterCount < reenterCallLimit) {
            reenterCount += 1;
            (bool ok,) = reenterTarget.call(reenterData);
            ok;
        }

        return forcedBalance[id][account];
    }
}
