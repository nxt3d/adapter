# Adapter8004 Counterfactual + Event-Coverage + Reentrancy Upgrade Report - 2026-05-15

## Summary

UUPS upgrade rolling out the counterfactual ERC-8004 registration surface, full on-chain event coverage, and OZ v5 `ReentrancyGuard` (ERC-7201 namespaced) protection on every state-mutating external function. The new implementation:

- Adds a counterfactual register family (`counterfactualRegister` and the five `counterfactual*` setters) that mirrors the on-chain register surface but emits events only — no SSTORE, no ERC-8004 registry calls. Indexers consume the emitted events as soft-state claims keyed by a deterministic `registrationHash(chainid, adapter, tokenContract, tokenId)`.
- Exposes the canonical `registrationHash(address tokenContract, uint256 tokenId) external view returns (bytes32)` so off-chain consumers do not re-implement the encoding rules.
- Tightens the existing on-chain surface: every state-mutating external function now emits exactly one adapter-level event (`AgentURISet`, `MetadataSet`, `AgentWalletSet`, `AgentWalletUnset`, `BindingMetadataRewritten` alongside the existing `AgentBound`, `MetadataBatchSet`, `IdentityRegistryUpdated`).
- Applies `nonReentrant` to every state-mutating external function — on-chain and counterfactual — via OZ v5 `ReentrancyGuard`. The guard's storage lives at the ERC-7201 namespaced slot (`0x9b779b...`), so the adapter's regular storage layout is unchanged.
- Declares the counterfactual events on a dedicated `IERC8004AdapterCounterfactual` interface; the on-chain events stay on `Adapter8004` itself.

This report supplements the prior [2026-05-07-erc8004-coverage-upgrade-report.md](./2026-05-07-erc8004-coverage-upgrade-report.md). It only replaces the implementation behind each proxy. Proxy addresses, owner, and the underlying ERC-8004 IdentityRegistry addresses are unchanged.

Owner / deployer (unchanged across all networks):

- `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

Implementation source: commit [`a20035c`](https://github.com/nxt3d/adapter/commit/a20035c) on `main`. Local-only until the operator pushes.

Storage layout verified identical before and after the upgrade via `forge inspect Adapter8004 storage-layout` (SHA-256 `61f0912c13f31c8d66370291b3abb2ac9223f70d38074df39f6dc88114382f72` — byte-identical to the 2026-05-07 baseline). Regular slots remain `identityRegistry` at slot 0 and `_bindings` at slot 1; `ReentrancyGuard` uses ERC-7201 namespaced storage and does not appear in the regular layout.

## Base

- Date (UTC): `2026-05-15 04:39:29`
- Chain ID: `8453`
- Adapter proxy: `0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27`
- Previous implementation (rolled out 2026-05-07): `0x7Cdba6F5f1c1214E28cba57dbAdF72D810838cf2`
- New implementation: `0x0f81bd4EDD4879734361A1A44460264CBf6F94c9`
- New implementation deployment tx: `0xf4a48bbdbed72803fe1681feec3df9ccf599272437348a1e088fd3cdf36d8fd4`
- `upgradeToAndCall` tx: `0x00f625e07674a7b7acd7ac9a72f9ac58636a032a7fad8bf4812377331d829f04`
- Block: `46015311`
- Verification URL: https://basescan.org/address/0x0f81bd4edd4879734361a1a44460264cbf6f94c9
- Gas spent: `2,892,963` gas (`0.00001524591501 ETH` at `5,270,000` wei effective gas price)
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/8453/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/8453/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0x0f81bd4edd4879734361a1a44460264cbf6f94c9`
  - Direct read of EIP-1967 implementation slot `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` returned `0x0000000000000000000000000f81bd4edd4879734361a1a44460264cbf6f94c9`
  - Smoke test `registrationHash(0xdEaD, 0)` returned `0x723bd01674df0d12167a0bcd7db900b2ea5263f21a0e3b506c9a620e875a3faa`

## Sepolia

- Date (UTC): `2026-05-15 04:40:36`
- Chain ID: `11155111`
- Adapter proxy: `0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92`
- Previous implementation (rolled out 2026-05-07): `0xdf8a3d51526B9a77B82d9295057e1907A916811f`
- New implementation: `0xFa8b53E82F6F1e17aDdFB5Db56f9eA26B24f4c4D`
- New implementation deployment tx: `0x019a164315881e18ce80a3ee37a97716e07b5448e1881fd42e28f651f78560bc`
- `upgradeToAndCall` tx: `0xcba415b228a940cab8148db59de60f89b2075243ba23d3ec9c71e7ae31f1e210`
- Block: `10855262`
- Verification URL: https://sepolia.etherscan.io/address/0xfa8b53e82f6f1e17addfb5db56f9ea26b24f4c4d
- Gas spent: `2,892,963` gas (`0.000002893015073334 ETH` at `1,000,018` wei effective gas price)
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0xfa8b53e82f6f1e17addfb5db56f9ea26b24f4c4d`
  - Direct read of EIP-1967 implementation slot returned `0x000000000000000000000000fa8b53e82f6f1e17addfb5db56f9ea26b24f4c4d`
  - Smoke test `registrationHash(0xdEaD, 0)` returned `0x53f549eed10d762aecb2661041b2cc7d7dfe47b910c8e491e460894e536b7de0`

## Ethereum Mainnet

- Date (UTC): `2026-05-15 04:41:47`
- Chain ID: `1`
- Adapter proxy: `0xde152AfB7db5373F34876E1499fbD893A82dD336`
- Previous implementation (rolled out 2026-05-07): `0x445229facce32c7De3795c863032C64cC8b79213`
- New implementation: `0xa6D23f27D3b1780B12488482a008cB3c3787135f`
- New implementation deployment tx: `0x56fe2d0fcce151635dfccce9edfe005ce8235c6576c869da0701112ba5987959`
- `upgradeToAndCall` tx: `0x7c389f9957bbd55cea496784e08ef473ee759fb901483201ac98faf305c03458`
- Block: `25098221`
- Verification URL: https://etherscan.io/address/0xa6d23f27d3b1780b12488482a008cb3c3787135f
- Gas spent: `2,892,963` gas (`0.00032763286206858 ETH` at `113,251,660` wei effective gas price)
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/1/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/1/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0xa6d23f27d3b1780b12488482a008cb3c3787135f`
  - Direct read of EIP-1967 implementation slot returned `0x000000000000000000000000a6d23f27d3b1780b12488482a008cb3c3787135f`
  - Smoke test `registrationHash(0xdEaD, 0)` returned `0xcd59ccbec0b69ba2ae57b83b9400886c37d64001e737ef2867746ce201cd4af0`

## Rollback Implementations

If rollback becomes necessary, each network can `upgradeToAndCall` back to its previous (2026-05-07 ERC-8004-coverage) implementation. Storage layout is unchanged so rollback is safe.

| Network | Previous implementation |
| --- | --- |
| Sepolia | `0xdf8a3d51526B9a77B82d9295057e1907A916811f` |
| Base | `0x7Cdba6F5f1c1214E28cba57dbAdF72D810838cf2` |
| Mainnet | `0x445229facce32c7De3795c863032C64cC8b79213` |
