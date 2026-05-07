# TOB Differential Review - Adapter ERC-8004 Coverage

Date: 2026-05-07
Task: audit-adapter-erc8004-coverage
Repo: `/Users/nxt3d/projects/adapter`
Scope: working-tree diff only

## Executive Summary

The scoped diff adds adapter-facing ERC-8004 interfaces and forwards four read methods from `Adapter8004` to the configured identity registry. I found one low-severity interface-completeness issue: the registry interface only declares the metadata-array registration overload, while the current ERC-8004 Identity Registry specification also defines `register(string)` and `register()`.

No high-impact runtime vulnerability was introduced by the diff. The new adapter read forwarders are permissionless reads into an already-public registry surface. The mutation paths still pass through the adapter's bound-token controller checks before forwarding to the registry.

Token transfer / approval / balance flows: skipped `token-integration-analyzer`. The diff did not change token transfer, approval, or balance handling logic; it only added interfaces, view forwarders, and override/interface wiring.

## Template Application Notes

- Requested Source A `/Users/nxt3d/projects/id2/id-agents/configs/agents/pashov-solidity-security/` exists but contains only `skills/solidity-auditor/.DS_Store`; no `SKILL.md` or `pag-*.md` files were available from that exact source.
- Requested Source B `/Users/nxt3d/projects/id2/id-agents/configs/agents/tob-solidity-security/` does not exist locally.
- Usable local equivalents were copied without overwriting unrelated adapter `.claude` files:
  - TOB-style `differential-review` from `configs/agents/security/skills/differential-review`.
  - Pashov-style `solidity-auditor` and `x-ray` from `configs/agents/solidity-security/skills`.
- Post-copy reachable skills include `.claude/skills/differential-review/SKILL.md`, `.claude/skills/solidity-auditor/SKILL.md`, and `.claude/skills/x-ray/SKILL.md`.
- No `pag-*.md` files were found anywhere under `/Users/nxt3d/projects/id2/id-agents`.

## Severity Counts

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 1 |
| Informational | 3 |

## Findings

### L-01 - `IERC8004IdentityRegistry` omits two ERC-8004 registration overloads

Severity: Low
Confidence: High

Evidence:
- `src/interfaces/IERC8004IdentityRegistry.sol:12` declares only `register(string memory agentURI, MetadataEntry[] memory metadata)`.
- Current ERC-8004 Identity Registry spec lists three registration entry points: `register(string agentURI, MetadataEntry[] calldata metadata)`, `register(string agentURI)`, and `register()`.
- The newly added adapter registration interface at `src/interfaces/IERC8004AdapterRegistration.sol:11-17` intentionally defines the adapter's bound-token registration signature, not the registry's native overloads.

Impact:
Solidity consumers importing `IERC8004IdentityRegistry` cannot type-check calls to the two shorter native registry overloads even though those overloads are part of the current ERC-8004 Identity Registry surface. This is an interface-coverage gap rather than an exploitable runtime flaw in `Adapter8004`, because the adapter itself only needs the metadata-array overload at `src/Adapter8004.sol:103`.

Recommended fix:
Add the two missing overloads to `IERC8004IdentityRegistry`:

```solidity
function register(string memory agentURI) external returns (uint256 agentId);
function register() external returns (uint256 agentId);
```

Update mocks/tests if they are intended to model the full ERC-8004 registry surface.

## Informational Notes

### I-01 - The adapter read forwarders are intentionally public

Evidence:
- `src/Adapter8004.sol:118-135` forwards `getMetadata`, `getAgentWallet`, `ownerOf`, and `tokenURI` to `identityRegistry`.

Assessment:
These are view functions on public registry data. They do not bypass the adapter's mutation authorization model, because writes still route through `_requireController` at `src/Adapter8004.sol:138-203`.

### I-02 - Adapter exposes `ownerOf`/`tokenURI` selectors but is not an ERC-721

Evidence:
- `src/Adapter8004.sol:130-135` exposes ERC-721-like read selectors as forwarding helpers.
- The adapter does not advertise ERC-721 support in ERC-165 and does not implement the full ERC-721 surface.

Assessment:
This is acceptable if documented as ERC-8004 read forwarding. Integrators should not infer that `Adapter8004` itself is an ERC-721 token contract.

### I-03 - Add explicit interface-cast and revert-forwarding coverage

Evidence:
- `test/Adapter8004.t.sol:83-87` checks happy-path adapter read forwarding against the mock registry.

Assessment:
Existing tests prove the concrete adapter call path. For stronger interface conformance, add tests that cast the adapter to `IERC8004IdentityRecord` and call every record function through the interface. Add a reverting registry mock for the new read forwarders so regressions in revert propagation are caught.

## False Positives / Non-Issues

- `setMetadata` changed from calldata parameters to memory parameters in `src/Adapter8004.sol:146` to satisfy `IERC8004IdentityRecord`; this changes ABI-equivalent external inputs and does not create an authorization bypass.
- `override` keywords were removed from `bindingOf` and `onERC721Received` in the diff, but Solidity still accepts the implementations through inherited interface matching; `forge build` passes.
- No token transfer / approval / balance implementation changed. Existing tests using mock ERC-721 transfers are not production token-flow changes.

## Verification

- `forge build` passed on 2026-05-07.
- Build emitted lint notes and test-only unchecked-transfer warnings, but no compile errors.
- TOB lane also ran `forge test --out /tmp/adapter-forge-out --cache-path /tmp/adapter-forge-cache`; result: 91 passed, 0 failed.
