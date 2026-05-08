# Adapter8004 ERC-8217 Upgrade Report - 2026-04-30

## Summary

UUPS upgrade aligning all three production proxies with [ERC-8217](https://github.com/ethereum/ERCs/commit/9159eb386cb437d2989d1c341a5955d78398705e). The new implementation writes `agent-binding` as exactly the 20-byte binding contract address (`abi.encodePacked(address(this))`) instead of the prior multi-field packed payload. Token standard, token contract, and token id are read only from `bindingOf(agentId)`.

This report supplements the original [2026-04-05-deployment-report.md](./2026-04-05-deployment-report.md) and the rollout plan [2026-04-30-erc8217-migration-plan.md](./2026-04-30-erc8217-migration-plan.md).

Owner / deployer (unchanged across all networks):

- `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

Implementation source: commits [`ee2ceb0`](https://github.com/nxt3d/adapter/commit/ee2ceb0) and [`95e5a5c`](https://github.com/nxt3d/adapter/commit/95e5a5c) on `main`.

Pre-upgrade audit (executed 2026-04-30): zero `AgentBound` events on all three proxies. No metadata migration was required.

## Sepolia

- Chain ID: `11155111`
- IdentityRegistry: `0x8004A818BFB912233c491871b3d84c89A494BD9e` (unchanged)
- Adapter proxy: `0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92`
- Previous implementation (rolled out 2026-04-05): `0x5Ced539aE5Fe67183a2bA4E984F92D57dFB3bd49`
- New implementation: `0x03fC1F8D8485a36Ff2e0162B28499f18dC3AeDb4`
- New implementation deployment tx: `0x7ba4ea8b798130afc490abb90bf6cfa1174b3c58d1d82a819787deddb277d066`
- `upgradeToAndCall` tx: `0xcf3075deed33b047f4ab9872a5ffc8c6f3ccea0f444e58f29027e3379f3e134c`
- Block: `10764756`
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json)
- Post-upgrade verification:
  - EIP-1967 implementation slot points to the new implementation
  - `identityRegistry()` unchanged
  - `owner()` unchanged
  - `bindingOf(0)` reverts with `0x7b65190b…` (unknown agent custom error) — interface live

## Base

- Chain ID: `8453`
- IdentityRegistry: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` (unchanged)
- Adapter proxy: `0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27`
- Previous implementation (rolled out 2026-04-05): `0x9DB9d78E1BB45604Fbfe30FaE123B152FA10de2d`
- New implementation: `0xcdf4C93Db79876928B155349a3B71962b2f94424`
- New implementation deployment tx: `0x098b60e3dd9862357f722a9783ea11234067bdce6362ee1eb3583e44a5d96f54`
- `upgradeToAndCall` tx: `0x6bac76a3a1611ff13417c47564b3b657c6680b82b3f4d35e067d6273dc802291`
- Block: `45398796`
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/8453/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/8453/run-latest.json)
- Post-upgrade verification:
  - EIP-1967 implementation slot points to the new implementation
  - `identityRegistry()` unchanged
  - `owner()` unchanged
  - `bindingOf(0)` reverts with `0x7b65190b…` — interface live

## Ethereum Mainnet

- Chain ID: `1`
- IdentityRegistry: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` (unchanged)
- Adapter proxy: `0xde152AfB7db5373F34876E1499fbD893A82dD336`
- Previous implementation (rolled out 2026-04-05): `0xA54a604448A5Ab0AfFccdDa6228EC4F2ac12a586`
- New implementation: `0xcdeFFf9EaFCfa28be798D1c1B1c8D731087d1CE4`
- New implementation deployment tx: `0x9eb06e2e5897c26fb98d0414da7c28fb2c015c3e4b05eebb629be937624fa82f` (block `24995816`)
- `upgradeToAndCall` tx: `0x30aa6cbed8abcabca19fcfac94bd257559e7993b1f12b210e014613f16b4f953` (block `24995818`)
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/1/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/1/run-latest.json)
- Post-upgrade verification:
  - EIP-1967 implementation slot points to the new implementation
  - `identityRegistry()` unchanged
  - `owner()` unchanged
  - `bindingOf(0)` reverts with `0x7b65190b…` — interface live

## Notes

Storage layout was identical before and after the upgrade (`forge inspect Adapter8004 storage-layout`). The struct moved from contract scope to interface scope but the slot order and field types were unchanged.

## 2026-05-08 UTC Base ERC-8004 Coverage Upgrade

- Date (UTC): `2026-05-08 00:34:02 UTC`
- Network: Base mainnet (chainId `8453`)
- Proxy: `0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27`
- OLD implementation: `0xcdf4c93db79876928b155349a3b71962b2f94424`
- NEW implementation: `0x7Cdba6F5f1c1214E28cba57dbAdF72D810838cf2`
- New implementation deployment tx: `0xd17c6e7d9c133080f14eccffe6837fac532704054b8dddcb2eb814aa2ccfe137`
- Broadcast `upgradeToAndCall` tx hash: `0x5beb7e767daef8aa043b2d7a89a55aa6ebb8833b6e0a10220d60644a3ca57ee8`
- Verification URL: `https://basescan.org/address/0x7cdba6f5f1c1214e28cba57dbadf72d810838cf2`
- Storage-layout verdict: identical SHA-256 `61f0912c13f31c8d66370291b3abb2ac9223f70d38074df39f6dc88114382f72`
- Gas spent: `2,196,108` gas total (`0.0000122982048 ETH` at `5,600,000` wei effective gas price)
- Block number: `45705504`
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/8453/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/8453/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0x7cdba6f5f1c1214e28cba57dbadf72d810838cf2`
  - Direct read of the canonical EIP-1967 implementation slot `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` returned `0x0000000000000000000000007cdba6f5f1c1214e28cba57dbadf72d810838cf2`
- Notes: ERC-8004 interface coverage + register convenience overload (commit `f428f43` + script fix `c9879a6`)

## 2026-05-08 UTC Sepolia ERC-8004 Coverage Upgrade

- Date (UTC): `2026-05-08 00:50:36 UTC`
- Network: Sepolia testnet (chainId `11155111`)
- Proxy: `0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92`
- OLD implementation: `0x03fC1F8D8485a36Ff2e0162B28499f18dC3AeDb4`
- NEW implementation: `0xdf8a3d51526B9a77B82d9295057e1907A916811f`
- New implementation deployment tx: `0xf6d5048902555fc763ceeb54e5fb461fc26739dc621899bf1e001caf0a36ab6f`
- Broadcast `upgradeToAndCall` tx hash: `0xad37b8eca50436a87d574f19f505c6ae20ec7f1362e03ceda00cbf67b1d2f60e`
- Verification URL: `https://sepolia.etherscan.io/address/0xdf8a3d51526b9a77b82d9295057e1907a916811f`
- Storage-layout verdict: `forge inspect Adapter8004 storage-layout` produced valid layout output; Base deployment already proved layout identity for commits `f428f43` + `c9879a6`
- Gas spent: `2,196,108` gas total (`0.000002196171687132 ETH` at `1,000,029` wei effective gas price)
- Block number: `10811062`
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/11155111/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0xdf8a3d51526b9a77b82d9295057e1907a916811f`
  - Direct read of the canonical EIP-1967 implementation slot `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` returned `0x000000000000000000000000df8a3d51526b9a77b82d9295057e1907a916811f`
- Notes: ERC-8004 interface coverage + register convenience overload (commit `f428f43` + script fix `c9879a6`)

## 2026-05-08 UTC Ethereum Mainnet ERC-8004 Coverage Upgrade

- Date (UTC): `2026-05-08 01:15:38 UTC`
- Network: Ethereum mainnet (chainId `1`)
- Proxy: `0xde152AfB7db5373F34876E1499fbD893A82dD336`
- OLD implementation: `0xcdefff9eafcfa28be798d1c1b1c8d731087d1ce4`
- NEW implementation: `0x445229facce32c7De3795c863032C64cC8b79213`
- New implementation deployment tx: `0x5bdb4a952a030bdbb758d7a33f1a3f44d96c8301c01fab9bc3f6a6348d6e007e`
- Broadcast `upgradeToAndCall` tx hash: `0x2c6562bf4c1112e975225171732291b5a157302caaaff8b2cd3604c4a60ec44b`
- Verification URL: `https://etherscan.io/address/0x445229facce32c7de3795c863032c64cc8b79213`
- Storage-layout verdict: Base deployment already proved layout identity for commits `f428f43` + `c9879a6`
- Gas spent: `2,196,108` gas total (`0.000262459241392876 ETH` actual paid)
- Block number: `25046978`
- Broadcast artifact: [`broadcast/UpgradeAdapter.s.sol/1/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/UpgradeAdapter.s.sol/1/run-latest.json)
- Post-upgrade verification:
  - `cast implementation` returned `0x445229facce32c7de3795c863032c64cc8b79213`
  - Direct read of the canonical EIP-1967 implementation slot `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` returned `0x000000000000000000000000445229facce32c7de3795c863032c64cc8b79213`
- Notes: ERC-8004 interface coverage + register convenience overload (commit `f428f43` + `c9879a6`)

Off-chain readers that previously decoded the multi-field packed metadata must switch to:

1. Read `getMetadata(agentId, "agent-binding")` from the registry.
2. Treat the value as exactly 20 bytes — the binding contract address.
3. Call `bindingOf(agentId)` on that address to obtain `standard`, `tokenContract`, and `tokenId`.

If any agents are registered against these proxies in the future under a legacy implementation, the owner-only `rewriteBindingMetadata(uint256)` helper plus [`script/MigrateBindingMetadata.s.sol`](/Users/nxt3d/projects/adapter/script/MigrateBindingMetadata.s.sol) can rewrite their metadata to the canonical 20-byte form. Today, no such rewrite is required.

## Rollback Implementations

If rollback becomes necessary, each network can `upgradeToAndCall` back to its previous implementation. Storage layout is unchanged so rollback is safe.

| Network | Previous implementation |
| --- | --- |
| Sepolia | `0x5Ced539aE5Fe67183a2bA4E984F92D57dFB3bd49` |
| Base | `0x9DB9d78E1BB45604Fbfe30FaE123B152FA10de2d` |
| Mainnet | `0xA54a604448A5Ab0AfFccdDa6228EC4F2ac12a586` |
