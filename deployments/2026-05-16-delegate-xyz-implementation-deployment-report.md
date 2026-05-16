# Adapter8004 delegate.xyz Implementation Deployment Report - 2026-05-16

## Status: PARTIAL — Sepolia and Base deployed; Ethereum Mainnet DEFERRED (awaiting lower gas)

This is **Step 1 only** of the delegate.xyz upgrade
([`2026-05-16-delegate-xyz-upgrade-runbook.md`](./2026-05-16-delegate-xyz-upgrade-runbook.md)):
the deployer EOA deploys the new `Adapter8004` implementation contracts. No
`upgradeToAndCall` was executed, no Safe transaction was submitted, and no
proxy was touched on any chain.

- Sepolia — implementation deployed and Etherscan-verified.
- Base — implementation deployed and Etherscan-verified.
- Ethereum Mainnet — **NOT deployed — intentionally deferred.** Mainnet gas
  is high at present, so the team has decided to wait for cheaper gas before
  deploying the mainnet implementation. The CREATE transaction was never
  broadcast (0 receipts) and no proxy was touched. The deployer EOA also
  needs additional ETH before the deploy can proceed (see the Mainnet
  section). This will be picked up later when gas prices are lower.

Implementation source: commit `4647ddd` on `main`.

Deployer EOA: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

Upgrade owner / Safe (all chains): `0x03302Df40186D9B85faEA4fbb6cC5da028B23149`
(Gnosis Safe v1.4.1, threshold 2).

## Sepolia — DEPLOYED

- Date (UTC): `2026-05-16 15:12:12`
- Chain ID: `11155111`
- Adapter proxy: `0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92`
- New implementation: `0x31a68E5bc0224ad081d6Ec20229B05F558609257`
- Deployment tx: `0x381e130c61fd21b78f9bf541a7da74425be83adaf1412bfb9a930a48108cfd08`
- Block: `10863505`
- Gas used: `2,837,498` (`0.000002837685274868 ETH` at `1,000,066` wei effective gas price)
- Pre-upgrade implementation (rollback target): `0xFa8b53E82F6F1e17aDdFB5Db56f9eA26B24f4c4D`
- Etherscan verification: verified — https://sepolia.etherscan.io/address/0x31a68e5bc0224ad081d6ec20229b05f558609257
- Broadcast artifact: [`broadcast/DeployAdapterImplementation.s.sol/11155111/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/DeployAdapterImplementation.s.sol/11155111/run-latest.json)

## Base — DEPLOYED

- Date (UTC): `2026-05-16 15:12:43`
- Chain ID: `8453`
- Adapter proxy: `0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27`
- New implementation: `0x0e30C112cbd52CeC452ee6a8C2DF87dC1bB64034`
- Deployment tx: `0x18af177da8889fb38694ff4fba602d99548c01173ad84725be555a0536a0cf9b`
- Block: `46077508`
- Gas used: `2,837,498` (`0.000016315610662502 ETH` at `5,749,999` wei effective gas price)
- Pre-upgrade implementation (rollback target): `0x0f81bd4EDD4879734361A1A44460264CBf6F94c9`
- Etherscan verification: verified — https://basescan.org/address/0x0e30c112cbd52cec452ee6a8c2df87dc1bb64034
- Broadcast artifact: [`broadcast/DeployAdapterImplementation.s.sol/8453/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/DeployAdapterImplementation.s.sol/8453/run-latest.json)

## Ethereum Mainnet — DEFERRED (not deployed, awaiting lower gas)

- Chain ID: `1`
- Adapter proxy: `0xde152AfB7db5373F34876E1499fbD893A82dD336`
- New implementation: **not deployed**
- Deployment tx: **none broadcast** — `forge script` aborted before sending
  with `error code -32003: insufficient funds for gas * price + value`.
- Deployer EOA mainnet balance at time of attempt: `5,560,930,512,945,936` wei
  (~`0.00556 ETH`).
- Estimated amount required: `10,604,990,285,185,462` wei (~`0.01060 ETH`).
- Shortfall: ~`0.00504 ETH`.
- Pre-upgrade implementation (current, unchanged): `0xa6D23f27D3b1780B12488482a008cB3c3787135f`
- Proxy EIP-1967 implementation slot re-read after the failure:
  `0x000000000000000000000000a6d23f27d3b1780b12488482a008cb3c3787135f`
  — unchanged, confirming nothing was touched on mainnet.

### Deferral decision

Mainnet deployment is **intentionally deferred until gas prices are lower.**
Ethereum mainnet gas is high at the time of this report, and the mainnet
implementation deploy is not time-critical (the Sepolia and Base rollout can
proceed independently). The team will return to the mainnet deploy when gas
is cheaper.

### Required to proceed (when resuming)

When gas conditions are favorable, fund the deployer EOA
`0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF` on Ethereum mainnet with enough
ETH for the deploy at the gas price prevailing then (the ~`0.0106 ETH`
estimate above was at the time of the blocked attempt; recheck before
funding, and add margin). Then re-run Step 1 for mainnet only:

```bash
ADAPTER_PROXY_ADDRESS=0xde152AfB7db5373F34876E1499fbD893A82dD336 \
  forge script script/DeployAdapterImplementation.s.sol:DeployAdapterImplementationScript \
  --rpc-url $MAINNET_RPC_URL --broadcast
```

Capture the printed new implementation address, deployment tx, block, and
`data` calldata, then finalize the mainnet row of the Step 2 instructions
below.

## Step 2 — Safe upgrade transactions (finalized for deployed chains)

Step 2 has NOT been executed. The following are the exact transactions the
Safe signers must submit. Rollout order: **Sepolia → Base → Ethereum
Mainnet**. Do not advance until each chain's post-execution verification
passes.

`data` is the ABI encoding of `upgradeToAndCall(address,bytes)` — selector
`0x4f1ef286`, then the new implementation address, then offset `0x40`, then
bytes length `0x00` (empty initializer; the delegate.xyz change is
constants/logic only, no storage migration, confirmed in the runbook).

### Sepolia Safe transaction

- Safe: `0x03302Df40186D9B85faEA4fbb6cC5da028B23149` (chain `11155111`)
- `to`: `0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92`
- `value`: `0`
- `data`:
  `0x4f1ef28600000000000000000000000031a68e5bc0224ad081d6ec20229b05f55860925700000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000`
- Safe app: https://app.safe.global/transactions/queue?safe=sep:0x03302Df40186D9B85faEA4fbb6cC5da028B23149

### Base Safe transaction

- Safe: `0x03302Df40186D9B85faEA4fbb6cC5da028B23149` (chain `8453`)
- `to`: `0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27`
- `value`: `0`
- `data`:
  `0x4f1ef2860000000000000000000000000e30c112cbd52cec452ee6a8c2df87dc1bb6403400000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000`
- Safe app: https://app.safe.global/transactions/queue?safe=base:0x03302Df40186D9B85faEA4fbb6cC5da028B23149

### Ethereum Mainnet Safe transaction

- Safe: `0x03302Df40186D9B85faEA4fbb6cC5da028B23149` (chain `1`)
- `to`: `0xde152AfB7db5373F34876E1499fbD893A82dD336`
- `value`: `0`
- `data`: **pending** — finalize after the mainnet implementation is
  deployed. It will be `0x4f1ef286` + `pad32(<mainnet impl>)` +
  `0x…0040` + `0x…0000`.
- Safe app: https://app.safe.global/transactions/queue?safe=eth:0x03302Df40186D9B85faEA4fbb6cC5da028B23149

### Safe Transaction Builder steps (per chain)

1. Open the Safe app for the target chain (links above), connect a signer
   wallet that is a Safe owner.
2. New transaction → Transaction Builder → use the custom/raw transaction
   (advanced "enter custom data") mode.
3. Enter `to` (the proxy), `value` = `0`, and paste the `data` bytes
   exactly as listed above. Do not hand-build the calldata.
4. Review: confirm `to` is the proxy, `value` is `0`, and the embedded
   implementation address in `data` matches the deployed implementation
   for that chain.
5. Create / propose the transaction. A first owner signs it.
6. A second owner signs (threshold 2).
7. An owner executes the transaction.

### Post-execution verification (per chain, mandatory)

```bash
# Both must return the new implementation address for that chain.
cast implementation <proxy> --rpc-url <chain-rpc>
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <chain-rpc>

# Smoke reads against the upgraded proxy.
cast call <proxy> "registrationHash(address,uint256)(bytes32)" 0x000000000000000000000000000000000000dEaD 0 --rpc-url <chain-rpc>
cast call <proxy> "DELEGATE_REGISTRY()(address)" --rpc-url <chain-rpc>   # expect 0x00000000000000447e69651d841bD8D104Bed493
cast call <proxy> "DELEGATE_RIGHTS()(bytes32)" --rpc-url <chain-rpc>     # expect keccak256("adapter8004.manage")
```

If any check fails, STOP, do not advance to the next chain, and do not
attempt recovery with the deployer EOA.

## Rollback

If a regression is found post-upgrade, the Safe can `upgradeToAndCall` back
to the pre-upgrade implementation (`data = 0x`, storage layout unchanged).

| Chain | Rollback implementation |
| --- | --- |
| Sepolia | `0xFa8b53E82F6F1e17aDdFB5Db56f9eA26B24f4c4D` |
| Base | `0x0f81bd4EDD4879734361A1A44460264CBf6F94c9` |
| Ethereum Mainnet | `0xa6D23f27D3b1780B12488482a008cB3c3787135f` |

## Verification status and issues

- Sepolia implementation: Etherscan verified (`Pass - Verified`).
- Base implementation: Basescan verified (`Pass - Verified`).
- Mainnet implementation: not deployed, so not verifiable. Intentionally
  deferred until mainnet gas is cheaper; also requires deployer-EOA funding
  before it can proceed (see the Mainnet section).
- Pre-flight `forge build` and `forge test` both passed before deployment
  (162 tests, 0 failures) at HEAD `4647ddd` with a clean working tree.
- No proxy was modified on any chain; this task performed implementation
  deployments only.
