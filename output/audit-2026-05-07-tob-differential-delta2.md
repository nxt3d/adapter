# TOB Differential Review - Adapter ERC-8004 Delta 2

Date: 2026-05-07
Task: `audit-adapter-erc8004-delta2`
Repo: `/Users/nxt3d/projects/adapter`
Scope: staged delta only, reviewed with `git diff --cached HEAD`
Lane: TOB-style `differential-review` plus guidelines-advisor focus on visibility and data-location changes

## Executive Summary

No Critical, High, Medium, or Low severity security finding was identified in the staged delta.

The staged change adds an adapter convenience overload:

- `Adapter8004.register(TokenStandard,address,uint256,string)` at `src/Adapter8004.sol:124`

It also changes the canonical adapter registration function from `external` to `public`, changes its `metadata` argument from `calldata` to `memory`, and routes empty metadata registrations through the registry URI-only overload:

- canonical register: `src/Adapter8004.sol:84`
- empty metadata branch: `src/Adapter8004.sol:105`
- metadata-array branch: `src/Adapter8004.sol:108`

The new paths preserve the same authorization and binding sequence:

1. reject zero token contract, `src/Adapter8004.sol:91`
2. require current bound-token control, `src/Adapter8004.sol:97`
3. reject reserved `agent-binding` user metadata, `src/Adapter8004.sol:100`
4. register identity through the configured registry, `src/Adapter8004.sol:105`
5. store `_bindings`, `src/Adapter8004.sol:112`
6. write canonical `agent-binding`, `src/Adapter8004.sol:115`
7. unset the default agent wallet, `src/Adapter8004.sol:118`
8. emit `AgentBound`, `src/Adapter8004.sol:121`

## Severity Counts

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Informational | 4 |

## Differential Findings

No high-confidence security finding.

## Informational Notes

### I-01 - `external` to `public` does not create a new external entry point

Evidence:

- The canonical selector remains externally callable as before at `src/Adapter8004.sol:84`.
- The new convenience overload internally calls the canonical function at `src/Adapter8004.sol:130`.
- No other staged adapter function calls `register(...)` internally.

Assessment:

Changing the canonical function to `public` only enables internal dispatch from the new overload. The authorization check still evaluates `msg.sender` at `src/Adapter8004.sol:97`; because the internal call does not use `this.register(...)`, `msg.sender` remains the original external caller, not the adapter. I found no phantom-caller, access-control, or reentrancy issue from this visibility change.

### I-02 - `calldata` to `memory` changes gas shape, not trust boundaries

Evidence:

- Canonical `metadata` is now memory at `src/Adapter8004.sol:89`.
- `_requireNoReservedBindingKey` now accepts memory at `src/Adapter8004.sol:324`.
- The helper scans every entry and hashes each key at `src/Adapter8004.sol:326`.

Assessment:

The change causes external calls to decode the dynamic metadata array into memory before execution. That can increase caller-paid gas and makes very large arrays fail earlier through normal gas/memory limits, but it does not create an unbounded griefing vector against contract-held funds or shared state. The public entry point remains transaction-scoped and no persistent partial state is written before the scan.

### I-03 - Empty metadata registry dispatch preserves adapter post-conditions

Evidence:

- Empty metadata now calls `identityRegistry.register(agentURI)` at `src/Adapter8004.sol:106`.
- Mock URI-only registry overload delegates to `register(agentURI, new MetadataEntry[](0))` at `test/mocks/MockIdentityRegistry.sol:57`.
- The mock canonical register mints to `msg.sender` and sets default `agentWallet` to `msg.sender` at `test/mocks/MockIdentityRegistry.sol:37`.
- Adapter still writes `agent-binding` and unsets the wallet after either registry branch at `src/Adapter8004.sol:115` and `src/Adapter8004.sol:118`.

Assessment:

On the URI-only registry path, `msg.sender` at the registry remains the adapter because the adapter performs the external call. The adapter becomes the registry owner, then records the binding and clears the default wallet exactly as it did on the metadata-array path. The branch is path-disjoint only for the registry overload selector; adapter-side state effects converge before return.

### I-04 - Overloaded selectors are distinct and the adversarial test targets the intended selector

Selector check:

- `register(uint8,address,uint256,string,(string,bytes)[])`: `0x1fd8046a`
- `register(uint8,address,uint256,string)`: `0xb68ca002`
- `register(string,(string,bytes)[])`: `0x8ea42286`
- `register(string)`: `0xf2c298be`
- `register()`: `0x1aa3a008`

Evidence:

- The adversarial test uses `abi.encodeWithSignature("register(uint8,address,uint256,string,(string,bytes)[])", ...)` at `test/security/Adapter8004.adversarial.t.sol:142`.
- The outer reentry test still calls the five-argument adapter registration path at `test/security/Adapter8004.adversarial.t.sol:154`.

Assessment:

The old `abi.encodeCall(Adapter8004.register, ...)` would become ambiguous after adding the overload. The staged replacement fixes the test encoding and still reaches the intended five-argument reentry payload. I found no staged integration that dispatches by name only.

## Test Coverage Adequacy

The two new convenience-overload tests cover:

- happy-path identity binding, registry owner, URI, wallet clearing, canonical `agent-binding`, and `_bindings`: `test/Adapter8004.t.sol:148`
- token-control enforcement on the convenience overload: `test/Adapter8004.t.sol:164`

Coverage is adequate for this delta. Existing security and invariant tests also exercise empty metadata through the canonical function, which now covers the URI-only registry branch.

## Blocking Verdict

No new finding warrants blocking the commit.

## Verification

- `forge build`: passed on 2026-05-07.
- `forge test`: passed, 102 passed / 0 failed / 0 skipped.
