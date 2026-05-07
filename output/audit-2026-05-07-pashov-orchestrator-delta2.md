# Pashov Orchestrator Review - Adapter ERC-8004 Delta 2

Date: 2026-05-07
Task: `audit-adapter-erc8004-delta2`
Repo: `/Users/nxt3d/projects/adapter`
Scope: staged delta only, focused manual 8-perspective pass
Lane: Pashov-style `solidity-auditor` orchestrator

## Executive Summary

No Critical, High, Medium, or Low severity security finding was found in the staged delta.

The convenience overload and empty-metadata registry dispatch preserve the adapter's core invariants: bound-token control is checked before identity creation, `_bindings` is populated after successful registry registration, canonical `agent-binding` metadata is adapter-written, the ERC-8004 default wallet is cleared, and `AgentBound` is emitted.

## Severity Counts

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Informational | 5 |

## High-Confidence Findings

None.

## Manual 8-Perspective Pass

### 1. Access Control

Reviewed paths:

- canonical register: `src/Adapter8004.sol:84`
- convenience overload: `src/Adapter8004.sol:124`
- token-control check: `src/Adapter8004.sol:97`
- token-standard-specific control checks: `src/Adapter8004.sol:298`

The convenience overload does not skip token control. It internally calls the canonical function at `src/Adapter8004.sol:130`, preserving the original caller as `msg.sender`. Unauthorized callers still revert through `_requireBindingControl` with `NotController`.

Verdict: no access-control issue.

### 2. Reentrancy / External Calls

Reviewed external calls:

- bound-token ownership/balance static view calls through `_hasBindingControl`, `src/Adapter8004.sol:303`
- registry URI-only register, `src/Adapter8004.sol:106`
- registry metadata-array register, `src/Adapter8004.sol:108`
- registry post-registration metadata and wallet calls, `src/Adapter8004.sol:115` and `src/Adapter8004.sol:118`

The `public` visibility change does not add a new external selector; it only enables internal dispatch. The pre-existing registration flow still performs external registry calls before the binding is finalized, but this delta does not create a new caller-controlled callback surface. If the owner configures a malicious registry, that is the existing trusted-admin registry risk, not a delta-specific issue.

The staged adversarial test still proves token view-time reentry into the five-argument register path is blocked by staticcall, with the intended selector encoded at `test/security/Adapter8004.adversarial.t.sol:142`.

Verdict: no new reentrancy issue.

### 3. State Invariants

Expected register invariant:

- registry owner is adapter
- adapter `_bindings[agentId]` records `(standard, tokenContract, tokenId)`
- registry `agent-binding` metadata equals `abi.encodePacked(address(adapter))`
- registry `agentWallet` is unset
- event `AgentBound` records the original registering controller

Evidence:

- registry owner defaults to the adapter because the adapter calls the registry at `src/Adapter8004.sol:106` or `src/Adapter8004.sol:108`
- binding write: `src/Adapter8004.sol:112`
- canonical metadata write: `src/Adapter8004.sol:115`
- wallet clear: `src/Adapter8004.sol:118`
- event emission: `src/Adapter8004.sol:121`
- convenience overload test assertions: `test/Adapter8004.t.sol:148`

Verdict: invariants preserved.

### 4. Metadata / Reserved-Key Handling

Reviewed paths:

- register reserved-key scan: `src/Adapter8004.sol:100`
- helper memory scan: `src/Adapter8004.sol:324`
- single metadata write guard remains at `src/Adapter8004.sol:166`

`calldata` to `memory` does not weaken the reserved-key check. The helper hashes the same string values and reverts with the rejected key. Empty metadata still passes through the zero-length helper scan before the URI-only branch.

Verdict: no reserved-key bypass.

### 5. Gas / DoS

The canonical register now accepts `MetadataEntry[] memory`, so external callers pay to ABI-decode dynamic metadata into memory before the reserved-key scan and registry call. Large arrays can make the caller's transaction run out of gas, but no shared adapter state is written before the scan or before successful registry registration.

The empty-metadata branch reduces work by avoiding the metadata-array registry overload. There is no griefing gain for a malicious caller beyond spending their own gas.

Verdict: no security-relevant DoS issue.

### 6. Selector / ABI Integration

Selectors:

- adapter five-argument register: `0x1fd8046a`
- adapter four-argument register: `0xb68ca002`
- registry metadata-array register: `0x8ea42286`
- registry URI-only register: `0xf2c298be`
- registry bare register: `0x1aa3a008`

The staged Solidity search found no production dispatch by function name. The adversarial test switched from ambiguous `abi.encodeCall(Adapter8004.register, ...)` to a full signature at `test/security/Adapter8004.adversarial.t.sol:142`.

Verdict: no selector collision or wrong-overload dispatch issue.

### 7. Registry Compatibility / Path-Disjoint State

The adapter now calls `identityRegistry.register(agentURI)` whenever `metadata.length == 0` at `src/Adapter8004.sol:105`.

The local registry interface declares that overload at `src/interfaces/IERC8004IdentityRegistry.sol:14`, and the mock implements it by delegating to the metadata-array overload with an empty array at `test/mocks/MockIdentityRegistry.sol:57`.

This means a registry that only implements the older local metadata-array interface would fail empty-metadata adapter registrations after this delta. That is a compatibility consideration, not a security issue in the scoped staged code, because the updated interface now models the ERC-8004 overload surface and the configured registry is owner-controlled.

Verdict: no path-disjoint state desync; note registry implementation must support the URI-only overload.

### 8. Test Adequacy

New tests:

- `testRegisterNoMetadataOverloadProducesIdenticalBinding`, `test/Adapter8004.t.sol:148`
- `testRegisterNoMetadataOverloadEnforcesTokenControl`, `test/Adapter8004.t.sol:164`

Existing and staged tests relevant to the delta:

- adversarial reentry selector path: `test/security/Adapter8004.adversarial.t.sol:137`
- registry overload coverage: `test/Adapter8004.interfaces.t.sol:132`, `test/Adapter8004.interfaces.t.sol:145`, `test/Adapter8004.interfaces.t.sol:158`
- wallet-clearing invariant: `test/security/Adapter8004.invariants.t.sol:96`

Coverage is adequate for the new code paths.

## Lane-Specific Findings

No Pashov-lane security finding.

## Blocking Verdict

No new finding warrants blocking the commit.

## Verification

- `forge build`: passed on 2026-05-07.
- `forge test`: passed, 102 passed / 0 failed / 0 skipped.
