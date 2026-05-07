# Consolidated Audit - Adapter ERC-8004 Interface Coverage

Date: 2026-05-07
Task: audit-adapter-erc8004-coverage
Repo: `/Users/nxt3d/projects/adapter`
Branch: `main`
Source mode: read-only source review; reports written to `output/`

## Deliverables

- Raw TOB lane: `output/audit-2026-05-07-tob-differential.md`
- Raw Pashov lane: `output/audit-2026-05-07-pashov-orchestrator.md`
- Consolidated report: `output/audit-2026-05-07-pashov-tob.md`

## Severity Counts

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 1 |
| Informational | 3 |

## Interface-Coverage Verdict

Verdict: incomplete for the full ERC-8004 Identity Registry function surface.

Covered by the new interfaces:
- `setMetadata(uint256,string,bytes)` - `src/interfaces/IERC8004IdentityRecord.sol:12`
- `setAgentURI(uint256,string)` - `src/interfaces/IERC8004IdentityRecord.sol:14`
- `setAgentWallet(uint256,address,uint256,bytes)` - `src/interfaces/IERC8004IdentityRecord.sol:16`
- `unsetAgentWallet(uint256)` - `src/interfaces/IERC8004IdentityRecord.sol:18`
- `getMetadata(uint256,string)` - `src/interfaces/IERC8004IdentityRecord.sol:20`
- `getAgentWallet(uint256)` - `src/interfaces/IERC8004IdentityRecord.sol:22`
- `ownerOf(uint256)` - `src/interfaces/IERC8004IdentityRecord.sol:24`
- `tokenURI(uint256)` - `src/interfaces/IERC8004IdentityRecord.sol:26`
- `register(string, MetadataEntry[])` - `src/interfaces/IERC8004IdentityRegistry.sol:12`

Not covered:
- `register(string)` - current ERC-8004 Identity Registry registration overload.
- `register()` - current ERC-8004 Identity Registry registration overload.

Out of scope for this adapter-facing interface review:
- ERC-8004 Reputation Registry and Validation Registry functions.
- Full ERC-721 interface coverage beyond the identity reads the adapter chooses to forward.

Primary source checked: current EIP-8004 specification at https://eips.ethereum.org/EIPS/eip-8004.

## High-Confidence Findings (Both Lanes)

### L-01 - `IERC8004IdentityRegistry` omits two ERC-8004 registration overloads

Severity: Low
Confidence: High
Status: actionable

Evidence:
- `src/interfaces/IERC8004IdentityRegistry.sol:12` declares only `register(string memory agentURI, MetadataEntry[] memory metadata)`.
- `src/interfaces/IERC8004AdapterRegistration.sol:11-17` declares the adapter-specific bound-token registration function; it is not a substitute for the native ERC-8004 registry overloads.
- The current EIP-8004 Identity Registry spec lists `register(string, MetadataEntry[])`, `register(string)`, and `register()`.

Impact:
The repository's ERC-8004 registry interface is incomplete for typed consumers that need the full standard registration surface. The adapter runtime path is not directly vulnerable because `Adapter8004.register` calls only the metadata-array overload at `src/Adapter8004.sol:103`.

Recommended fix:
Add the two missing overloads to `IERC8004IdentityRegistry` and, if the mock is intended as a complete ERC-8004 mock, implement/test them in `MockIdentityRegistry`.

```solidity
function register(string memory agentURI) external returns (uint256 agentId);
function register() external returns (uint256 agentId);
```

## Lane-Specific Findings

### I-01 - Adapter read forwarding is public but state-safe

Severity: Informational
Lane: TOB + Pashov observation, not a vulnerability

Evidence:
- `src/Adapter8004.sol:118-135` adds read forwarders for metadata, wallet, owner, and token URI.
- Mutations remain gated through `_requireController` at `src/Adapter8004.sol:138-203`.

Recommendation:
No code fix required. Keep tests that compare adapter read results to registry read results.

### I-02 - ERC-721-like selectors on a non-ERC-721 adapter can confuse naive integrations

Severity: Informational
Lane: Pashov-specific integration note

Evidence:
- `src/Adapter8004.sol:130-135` exposes `ownerOf` and `tokenURI` as registry-forwarding helpers.
- The adapter does not implement the full ERC-721 surface.

Recommendation:
Document these functions as ERC-8004 registry-read forwarders. Do not advertise ERC-721 support unless the full interface and ERC-165 behavior are intentionally implemented.

### I-03 - Interface-cast and revert-forwarding tests would improve regression coverage

Severity: Informational
Lane: TOB-specific test coverage note

Evidence:
- `test/Adapter8004.t.sol:83-87` checks the new view forwarders on the concrete adapter instance.

Recommendation:
Add tests that cast `Adapter8004` to `IERC8004IdentityRecord` and exercise the record functions through that interface. Add a reverting registry mock for `getMetadata`, `getAgentWallet`, `ownerOf`, and `tokenURI` to prove the adapter preserves underlying registry revert behavior.

## False Positives With Rationale

- Token integration analyzer finding: not applicable. The diff did not alter token transfer, approval, or balance logic; it only added interface inheritance, read forwarders, and tests.
- `setMetadata` calldata-to-memory change: ABI-compatible for external callers and required to match `IERC8004IdentityRecord`; authorization remains unchanged.
- Reentrancy through `ownerOf`/`tokenURI` forwarders: rejected because the new functions are `view` and do not write adapter state.
- Reserved binding metadata bypass: rejected because new read paths cannot write metadata, and reserved-key write checks remain in `setMetadata` and `setMetadataBatch`.

## Template Verification

Requested template application was attempted with merge semantics and no source overwrite:
- Existing adapter `.claude/` was preserved.
- Existing unrelated `.claude/skills/*` and `.claude/agents/*` were not overwritten.
- Reachable post-copy files include:
  - `.claude/skills/differential-review/SKILL.md`
  - `.claude/skills/solidity-auditor/SKILL.md`
  - `.claude/skills/x-ray/SKILL.md`

Conflicts / missing inputs:
- `/Users/nxt3d/projects/id2/id-agents/configs/agents/tob-solidity-security/` did not exist.
- `/Users/nxt3d/projects/id2/id-agents/configs/agents/pashov-solidity-security/` contained no usable `SKILL.md` or `pag-*.md` files.
- No `pag-*.md` files were found under `/Users/nxt3d/projects/id2/id-agents`.

## Build Verification

Command: `forge build`

Result: pass. Foundry reported "No files changed, compilation skipped" and emitted lint notes/test-only unchecked-transfer warnings, but no compile errors.

Additional lane verification: the TOB worker ran `forge test --out /tmp/adapter-forge-out --cache-path /tmp/adapter-forge-cache`; result was 91 passed, 0 failed.

## Phase 3 Recommendation

Do not start Phase 3 redeploy + website yet if the goal is strict full ERC-8004 Identity Registry interface coverage. First add the two missing registry registration overloads and rerun build/tests. If Phase 3 only depends on current adapter runtime behavior and not full typed registry coverage, this finding is non-blocking from a security standpoint.
