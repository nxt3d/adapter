# Pashov-Lane Audit: Adapter ERC-8004 Coverage

Date: 2026-05-07
Task: `audit-adapter-erc8004-coverage`
Lane: Pashov orchestrator, manual eight-perspective pass
Scope: working-tree changes around `src/Adapter8004.sol`, `src/interfaces/IERC8004IdentityRegistry.sol`, untracked `src/interfaces/IERC8004AdapterRegistration.sol`, untracked `src/interfaces/IERC8004IdentityRecord.sol`, and the directly updated tests/mocks.

## Executive Summary

No High or Medium severity vulnerabilities were found in the modified adapter integration. The added view passthroughs are read-only and the existing mutation paths remain controller-gated before forwarding to the ERC-8004 registry.

One Low severity interface-completeness issue was found: the refactored `IERC8004IdentityRegistry` still models only one of the three ERC-8004 registration overloads. This does not break `Adapter8004.register(...)`, because the adapter only calls the metadata-array overload, but it means the local ERC-8004 registry interface and mocks are not complete against the vendored ERC-8004 spec/reference implementation.

Static review only. I did not run `forge build` or tests because this lane was constrained to writing only this report under `output/` and optional `x-ray/`, and Foundry commands may write cache/artifact files outside that allowance.

## Scope Evidence

Working-tree delta:

- `src/Adapter8004.sol:12-23`: imports `IERC8004AdapterRegistration` and `IERC8004IdentityRecord`, then declares inheritance.
- `src/Adapter8004.sol:118-135`: adds `getMetadata`, `getAgentWallet`, `ownerOf`, `tokenURI` passthrough views.
- `src/interfaces/IERC8004IdentityRegistry.sol:4-12`: now inherits `IERC8004IdentityRecord` and only declares `register(string memory agentURI, MetadataEntry[] memory metadata)`.
- `src/interfaces/IERC8004AdapterRegistration.sol:7-17`: untracked adapter-specific registration interface.
- `src/interfaces/IERC8004IdentityRecord.sol:4-27`: untracked common record interface.
- `test/Adapter8004.t.sol:83-87`: happy-path view passthrough assertions added.
- `test/mocks/MockIdentityRegistry.sol:10`, `test/mocks/MockIdentityRegistry.sol:61-76`: override targets updated.

ERC-8004 reference surfaces used for comparison:

- Vendored spec: `lib/erc-8004-contracts/ERC8004SPEC.md:128-132`, `lib/erc-8004-contracts/ERC8004SPEC.md:144-151`, `lib/erc-8004-contracts/ERC8004SPEC.md:166-171`, `lib/erc-8004-contracts/ERC8004SPEC.md:186-188`.
- Vendored reference registry: `lib/erc-8004-contracts/contracts/IdentityRegistryUpgradeable.sol:60-79`, `lib/erc-8004-contracts/contracts/IdentityRegistryUpgradeable.sol:95-100`, `lib/erc-8004-contracts/contracts/IdentityRegistryUpgradeable.sol:114-167`.

## Findings

### [Low] `IERC8004IdentityRegistry` omits two ERC-8004 registration overloads

The refactored registry interface is still incomplete against the vendored ERC-8004 Identity Registry registration surface. The local interface declares only:

- `src/interfaces/IERC8004IdentityRegistry.sol:12` - `register(string memory agentURI, MetadataEntry[] memory metadata)`

The vendored ERC-8004 spec lists three registration functions:

- `lib/erc-8004-contracts/ERC8004SPEC.md:166` - `register(string agentURI, MetadataEntry[] calldata metadata)`
- `lib/erc-8004-contracts/ERC8004SPEC.md:168` - `register(string agentURI)`
- `lib/erc-8004-contracts/ERC8004SPEC.md:171` - `register()`

The vendored reference implementation also exposes all three:

- `lib/erc-8004-contracts/contracts/IdentityRegistryUpgradeable.sol:60` - `register()`
- `lib/erc-8004-contracts/contracts/IdentityRegistryUpgradeable.sol:69` - `register(string memory agentURI)`
- `lib/erc-8004-contracts/contracts/IdentityRegistryUpgradeable.sol:79` - `register(string memory agentURI, MetadataEntry[] memory metadata)`

Impact: Low. Runtime impact to `Adapter8004` is limited because `Adapter8004.register(...)` only needs the metadata-array overload and calls it at `src/Adapter8004.sol:103`. The issue is interface coverage and test coverage: local code that imports `IERC8004IdentityRegistry` cannot call the no-metadata or no-argument ERC-8004 registration overloads, and mocks implementing the local interface do not force those overloads to stay compatible with the spec.

Recommended fix:

- Add the missing overloads to `IERC8004IdentityRegistry`:
  - `function register(string memory agentURI) external returns (uint256 agentId);`
  - `function register() external returns (uint256 agentId);`
- Add matching implementations to `test/mocks/MockIdentityRegistry.sol` and minimal coverage proving the overloads exist.
- Keep `IERC8004AdapterRegistration` separate; the adapter-specific bound-token registration signature is correctly distinct from the registry registration surface.

Fix verification reasoning: Adding overload declarations does not alter storage or adapter control flow. The adapter call at `src/Adapter8004.sol:103` continues using the same selector for the metadata-array overload. Mock additions should mint exactly as the reference registry does, then existing adapter tests remain unchanged.

## Eight Perspectives

### 1. Vector Scan

Entry points introduced or affected:

- New read-only passthroughs: `getMetadata`, `getAgentWallet`, `ownerOf`, `tokenURI` at `src/Adapter8004.sol:118-135`.
- Existing controller-gated mutations: `setAgentURI`, `setMetadata`, `setMetadataBatch`, `setAgentWallet`, `unsetAgentWallet` at `src/Adapter8004.sol:138-203`.
- Existing admin-only registry repoint: `setIdentityRegistry` at `src/Adapter8004.sol:68-82`.

No new permissionless mutation was introduced. The new functions are `view` and forward to `identityRegistry`.

### 2. Math / Precision

No arithmetic or fixed-point math was introduced. The metadata batch loop at `src/Adapter8004.sol:167-170` is unchanged in behavior and bounded only by calldata size/gas. No precision finding.

### 3. Access Control

Controller-gated paths still call `_requireController(agentId, msg.sender)` before forwarding:

- `setAgentURI`: `src/Adapter8004.sol:138-143`
- `setMetadata`: `src/Adapter8004.sol:146-156`
- `setMetadataBatch`: `src/Adapter8004.sol:159-173`
- `setAgentWallet`: `src/Adapter8004.sol:188-195`
- `unsetAgentWallet`: `src/Adapter8004.sol:198-203`

The new view passthroughs intentionally have no caller restriction. No access-control vulnerability found.

### 4. Economic / Security

No token custody, fees, balances, price inputs, or economic accounting were added. The relevant security boundary remains: the adapter owns the ERC-8004 identity NFT in the underlying registry while external bound-token control determines who may mutate the record through the adapter. No economic finding.

### 5. Execution Trace

Primary registration trace:

1. Caller proves external token control at `src/Adapter8004.sol:96-100`.
2. Adapter calls `identityRegistry.register(agentURI, metadata)` at `src/Adapter8004.sol:103`.
3. Adapter stores `_bindings[agentId]` at `src/Adapter8004.sol:106`.
4. Adapter writes canonical `agent-binding` metadata at `src/Adapter8004.sol:109`.
5. Adapter clears the default wallet at `src/Adapter8004.sol:112`.

The new read trace is direct: `Adapter8004` calls the same function on `identityRegistry` and returns the result (`src/Adapter8004.sol:118-135`). No state is modified by the new paths.

### 6. Invariants

Relevant invariants still hold:

- `_bindings[agentId]` is only written during registration at `src/Adapter8004.sol:106`.
- `bindingOf` rejects unknown agents and returns the stored binding at `src/Adapter8004.sol:206-216`.
- The reserved `agent-binding` key is blocked on registration and user metadata writes at `src/Adapter8004.sol:99-100`, `:150-153`, `:163-164`, `:309-317`.

No invariant break was found in the modified files.

### 7. Periphery / Integration

The adapter's new `IERC8004IdentityRecord` inheritance now covers the ERC-8004 record read/write functions:

- Interface declarations: `src/interfaces/IERC8004IdentityRecord.sol:12-26`.
- Adapter implementations: `src/Adapter8004.sol:118-203`.

The remaining integration gap is the Low finding above: the underlying registry interface does not fully represent ERC-8004's three registration overloads. This is not exploitable through the adapter but can mislead downstream integrations and mocks about "complete ERC-8004 function coverage."

### 8. First Principles

The adapter is not a full ERC-8004 Identity Registry; it is a bound-token control adapter that forwards into one. From first principles, the safe shape is:

- Mutations must be gated by current bound-token control.
- Canonical binding metadata must not be forgeable by user metadata writes.
- Reads should faithfully reflect the underlying registry when callers intentionally query through the adapter.
- Interfaces should make the adapter-specific registration surface distinct from the registry's ERC-8004 registration surface.

The code satisfies the first three for the changed paths. The fourth is mostly satisfied by `IERC8004AdapterRegistration`, but the registry interface remains incomplete by omitting two overloads.

## False Positives / Non-Findings

- Missing `override` on interface implementations in `Adapter8004` is not a vulnerability. Solidity permits implementing interface functions without an explicit `override` specifier; a local `solc --standard-json` check against a minimal interface/contract confirmed this behavior. Existing `_authorizeUpgrade` still correctly uses `override` for inherited contract logic at `src/Adapter8004.sol:237`.
- The new `ownerOf(agentId)` passthrough returning the underlying registry owner is expected. For agents registered through the adapter, that owner is the adapter contract because the adapter calls the registry at `src/Adapter8004.sol:103`; README documents this custody model at `README.md:217`.
- The `setMetadata` calldata-to-memory change at `src/Adapter8004.sol:146` changes ABI-internal data location only; the external selector and behavior remain aligned with `IERC8004IdentityRecord.sol:12` and the ERC-8004 spec at `lib/erc-8004-contracts/ERC8004SPEC.md:131-132`.
- Admin registry repoint risk is pre-existing and owner-gated at `src/Adapter8004.sol:68-82`. It was not introduced by the ERC-8004 interface coverage changes.

## Recommended Fixes

1. Add the two missing ERC-8004 `register` overloads to `IERC8004IdentityRegistry`.
2. Update `MockIdentityRegistry` and any lightweight test registries that implement `IERC8004IdentityRegistry` so the compiler enforces complete registry coverage.
3. Add a focused test that casts the mock or vendored reference-compatible registry to `IERC8004IdentityRegistry` and exercises all three registration overloads.
4. Optional integration hardening: declare ERC-8004 events (`Registered`, `MetadataSet`, `URIUpdated`) in the registry/record interfaces so indexer-facing ABI generation is complete, even though event declarations do not affect runtime callability.

## Verdict

No exploitable High/Medium issue in the modified adapter code. One Low completeness issue should be fixed before calling the local interfaces "complete ERC-8004 coverage."
