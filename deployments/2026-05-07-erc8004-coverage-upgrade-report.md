# Adapter8004 ERC-8004 Coverage Upgrade Report - 2026-05-07

## Summary

UUPS upgrade aligning all three production proxies with the full ERC-8004 interface surface. The new implementation:

- Adds the spec's `register(string)` and `register()` overloads to `IERC8004IdentityRegistry`.
- Splits the read surface into `IERC8004IdentityRecord` (`getMetadata`, `getAgentWallet`, `ownerOf`, `tokenURI`) and adapter-specific `IERC8004AdapterRegistration`.
- Implements both `IERC8004IdentityRecord` and `IERC8004AdapterRegistration` on `Adapter8004`. The adapter now exposes the four record reads as direct view forwarders so an ERC-8004 client can talk to the adapter using the same interface it uses against the registry.
- Adds a `register(standard, tokenContract, tokenId, agentURI)` convenience overload equivalent to the canonical metadata-array form with an empty array.
- Skips the metadata-array overload at the registry call when `metadata.length == 0`, calling `identityRegistry.register(agentURI)` directly.

This report supplements the prior [2026-04-30-erc8217-upgrade-report.md](./2026-04-30-erc8217-upgrade-report.md). It only replaces the implementation behind each proxy. Proxy addresses, owner, and the underlying ERC-8004 IdentityRegistry addresses are unchanged.

Owner / deployer (unchanged across all networks):

- `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

Implementation source: commits [`f428f43`](https://github.com/nxt3d/adapter/commit/f428f43) and [`c9879a6`](https://github.com/nxt3d/adapter/commit/c9879a6) on `main`.

Storage layout verified identical before and after the upgrade via `forge inspect Adapter8004 storage-layout` (SHA-256 `61f0912c13f31c8d66370291b3abb2ac9223f70d38074df39f6dc88114382f72`). The diff added interfaces, view forwarders, and one register overload — none of which add storage.

## Base

- Date (UTC): `2026-05-08 00:34:02`
- Chain ID: `8453`
- Adapter proxy: `0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27`
- Previous implementation (rolled out 2026-04-30): `0xcdf4C93Db79876928B155349a3B71962b2f94424`
- New implementation: `0x7Cdba6F5f1c1214E28cba57dbAdF72D810838cf2`
- New implementation deployment tx: `0xd17c6e7d9c133080f14eccffe6837fac532704054b8dddcb2eb814aa2ccfe137`
- `upgradeToAndCall` tx: `0x5beb7e767daef8aa043b2d7a89a55aa6ebb8833b6e0a10220d60644a3ca57ee8`
- Block: `45705504`
- Verification URL: https://basescan.org/address/0x7cdba6f5f1c1214e28cba57dbadf72d810838cf2
- Gas spent: `2,196,108` gas (`0.0000122982048 ETH` at `5,600,000` wei effective gas price)
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/8453/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/8453/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0x7cdba6f5f1c1214e28cba57dbadf72d810838cf2`
  - Direct read of EIP-1967 implementation slot `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` returned `0x0000000000000000000000007cdba6f5f1c1214e28cba57dbadf72d810838cf2`

## Sepolia

- Date (UTC): `2026-05-08 00:50:36`
- Chain ID: `11155111`
- Adapter proxy: `0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92`
- Previous implementation (rolled out 2026-04-30): `0x03fC1F8D8485a36Ff2e0162B28499f18dC3AeDb4`
- New implementation: `0xdf8a3d51526B9a77B82d9295057e1907A916811f`
- New implementation deployment tx: `0xf6d5048902555fc763ceeb54e5fb461fc26739dc621899bf1e001caf0a36ab6f`
- `upgradeToAndCall` tx: `0xad37b8eca50436a87d574f19f505c6ae20ec7f1362e03ceda00cbf67b1d2f60e`
- Block: `10811062`
- Verification URL: https://sepolia.etherscan.io/address/0xdf8a3d51526b9a77b82d9295057e1907a916811f
- Gas spent: `2,196,108` gas (`0.000002196171687132 ETH` at `1,000,029` wei effective gas price)
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0xdf8a3d51526b9a77b82d9295057e1907a916811f`
  - Direct read of EIP-1967 implementation slot returned `0x000000000000000000000000df8a3d51526b9a77b82d9295057e1907a916811f`

## Ethereum Mainnet

- Date (UTC): `2026-05-08 01:15:38`
- Chain ID: `1`
- Adapter proxy: `0xde152AfB7db5373F34876E1499fbD893A82dD336`
- Previous implementation (rolled out 2026-04-30): `0xcdeFFf9EaFCfa28be798D1c1B1c8D731087d1CE4`
- New implementation: `0x445229facce32c7De3795c863032C64cC8b79213`
- New implementation deployment tx: `0x5bdb4a952a030bdbb758d7a33f1a3f44d96c8301c01fab9bc3f6a6348d6e007e`
- `upgradeToAndCall` tx: `0x2c6562bf4c1112e975225171732291b5a157302caaaff8b2cd3604c4a60ec44b`
- Block: `25046978`
- Verification URL: https://etherscan.io/address/0x445229facce32c7de3795c863032c64cc8b79213
- Gas spent: `2,196,108` gas (`0.000262459241392876 ETH` actual paid)
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/1/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/1/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0x445229facce32c7de3795c863032c64cc8b79213`
  - Direct read of EIP-1967 implementation slot returned `0x000000000000000000000000445229facce32c7de3795c863032c64cc8b79213`

## Rollback Implementations

If rollback becomes necessary, each network can `upgradeToAndCall` back to its previous (ERC-8217) implementation. Storage layout is unchanged so rollback is safe.

| Network | Previous implementation |
| --- | --- |
| Sepolia | `0x03fC1F8D8485a36Ff2e0162B28499f18dC3AeDb4` |
| Base | `0xcdf4C93Db79876928B155349a3B71962b2f94424` |
| Mainnet | `0xcdeFFf9EaFCfa28be798D1c1B1c8D731087d1CE4` |
