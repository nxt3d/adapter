# Consolidated Security Review - Adapter ERC-8004 Delta 2

Date: 2026-05-07
Task: `audit-adapter-erc8004-delta2`
Repo: `/Users/nxt3d/projects/adapter`
Target: staged changes on branch `main`, reviewed with `git diff --cached HEAD`

Raw lane reports:

- TOB differential: `output/audit-2026-05-07-tob-differential-delta2.md`
- Pashov orchestrator: `output/audit-2026-05-07-pashov-orchestrator-delta2.md`

## Executive Summary

No new security finding was identified in the Phase 2b staged delta. Both lanes agree that the convenience overload, canonical `public` visibility, `memory` metadata parameters, and empty-metadata registry dispatch preserve the adapter's registration invariants.

No new finding warrants blocking the commit.

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

## Lane Findings

TOB lane:

- No security finding.
- Informational notes only: visibility change is safe, memory data location is caller-paid gas shape only, empty-metadata dispatch preserves post-conditions, overloaded selectors are distinct.

Pashov lane:

- No security finding.
- Informational notes only: no new access-control, reentrancy, metadata, gas/DoS, selector, path-desync, or test-coverage issue.

Consolidation:

- Overlap is high confidence: both lanes independently found no blocking issue.
- Disjoint notes were informational and are not vulnerabilities.
- False positives documented: registry compatibility with implementations that lack `register(string)` is a deployment compatibility note, not a security finding in the staged code.

## Verdict On New Code Paths

### 1. Convenience adapter overload

Code: `src/Adapter8004.sol:124`

Verdict: safe in the scoped delta.

Reasoning: The overload internally calls the canonical function at `src/Adapter8004.sol:130`, preserving the external caller as `msg.sender`. The canonical path still rejects missing token control at `src/Adapter8004.sol:97`, then follows the same binding, metadata, wallet-clearing, and event sequence as the five-argument function.

Test coverage:

- binding identity and wallet-clearing assertions: `test/Adapter8004.t.sol:148`
- token-control rejection: `test/Adapter8004.t.sol:164`

### 2. Canonical register `external` to `public`

Code: `src/Adapter8004.sol:84`

Verdict: safe in the scoped delta.

Reasoning: No new external selector is created for the canonical function; it was already externally callable. The only new internal caller is the convenience overload. No staged function uses internal `register(...)` in a way that substitutes the adapter as caller or skips authorization.

### 3. Canonical `metadata` `calldata` to `memory`

Code: `src/Adapter8004.sol:89`, `src/Adapter8004.sol:324`

Verdict: safe in the scoped delta.

Reasoning: ABI semantics for external callers are unchanged. The caller pays for memory decoding and the reserved-key loop. Large metadata arrays can exhaust the caller's transaction gas, but no adapter state is written before the scan or before successful registry registration.

### 4. Empty-metadata registry `register(agentURI)` branch

Code: `src/Adapter8004.sol:105`

Verdict: safe in the scoped delta.

Reasoning: The registry call still comes from the adapter, so the ERC-8004 identity owner/default wallet are initially the adapter. The mock URI-only overload delegates to the metadata-array overload with an empty array at `test/mocks/MockIdentityRegistry.sol:57`. The adapter then converges with the metadata path by writing `_bindings` at `src/Adapter8004.sol:112`, writing canonical `agent-binding` at `src/Adapter8004.sol:115`, and clearing the default wallet at `src/Adapter8004.sol:118`.

Compatibility note: the configured identity registry must implement `register(string)`. The local interface now declares it at `src/interfaces/IERC8004IdentityRegistry.sol:14`.

### 5. Removed rationale comment

Verdict: no security impact.

Reasoning: The prior rationale about not wrapping bare registry overloads is obsolete after adding an adapter no-metadata overload.

### 6. Adversarial test selector change

Code: `test/security/Adapter8004.adversarial.t.sol:142`

Verdict: adequate.

Reasoning: The explicit signature selects `register(uint8,address,uint256,string,(string,bytes)[])` with selector `0x1fd8046a`. The new four-argument adapter overload has selector `0xb68ca002`, so the test no longer depends on ambiguous overloaded name resolution and still targets the intended reentry path.

### 7. New convenience-overload tests

Code: `test/Adapter8004.t.sol:148`, `test/Adapter8004.t.sol:164`

Verdict: adequate.

Reasoning: The first test checks registry owner, URI, cleared wallet, canonical binding metadata, and stored `_bindings`. The second test checks non-controller rejection through the new overload.

## Selector Review

Computed selectors:

- `register(uint8,address,uint256,string,(string,bytes)[])`: `0x1fd8046a`
- `register(uint8,address,uint256,string)`: `0xb68ca002`
- `register(string,(string,bytes)[])`: `0x8ea42286`
- `register(string)`: `0xf2c298be`
- `register()`: `0x1aa3a008`

No selector collision was found.

## Blocking Verdict

No. No new finding warrants blocking the commit.

## Verification

- `forge build`: passed on 2026-05-07.
- `forge test`: passed on 2026-05-07 with 102 passed / 0 failed / 0 skipped.

Reports were written under `output/` and were not committed.
