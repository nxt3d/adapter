# ERC-8217 v2026-04-05 — Gap Analysis vs `Adapter8004`

Sources read line-by-line:
- `/Users/nxt3d/projects/ERCs/ERCS/erc-agent-bindings.md` (draft v2026-04-05, 177 lines)
- `/Users/nxt3d/projects/adapter/src/Adapter8004.sol`
- `/Users/nxt3d/projects/adapter/src/interfaces/IERC8004IdentityRegistry.sol`
- `/Users/nxt3d/projects/adapter/test/Adapter8004.t.sol`
- `/Users/nxt3d/projects/adapter/test/security/Adapter8004.invariants.t.sol` (relevant ERC-8217 invariants)

Scope reminder: ERC-8217 standardizes (a) the metadata key, (b) the metadata payload format, and (c) the `bindingOf` interface. It does **not** standardize registration, URI updates, wallet binding, or upgrade controls (spec line 62).

---

## 1. Direct line-by-line compliance check

| Spec requirement (file: erc-agent-bindings.md) | Adapter location | Status |
|---|---|---|
| L46–50: `enum TokenStandard { ERC721, ERC1155, ERC6909 }` (exact order) | `Adapter8004.sol:17–21` | ✅ identical name + order |
| L52–56: `struct Binding { TokenStandard standard; address tokenContract; uint256 tokenId; }` | `Adapter8004.sol:23–27` | ✅ identical field names, types, order — ABI compatible |
| L58: `function bindingOf(uint256 agentId) external view returns (Binding memory);` | `Adapter8004.sol:178` | ✅ same selector + signature |
| L69: metadata key MUST be the literal string `agent-binding` | `Adapter8004.sol:14` (`BINDING_METADATA_KEY = "agent-binding"`) | ✅ exact |
| L74–78: metadata value MUST be exactly `abi.encodePacked(bindingContract)` (20 bytes) | `Adapter8004.sol:158–160` (`encodeBindingMetadata`) and `Adapter8004.sol:110` (`identityRegistry.setMetadata(... encodeBindingMetadata(address(this)))`) | ✅ payload is `abi.encodePacked(address(this))`, length 20 |
| L88, L97: stored address MUST match the contract that serves `bindingOf` for this agent | `Adapter8004.sol:110` writes `address(this)`; `Adapter8004.sol:178` is the `bindingOf` impl on the same contract | ✅ tautologically correct — adapter writes its own address and is itself the binding contract |
| L98: treat `agent-binding` as reserved against untrusted overwrite | Three guards: `register` via `_requireNoReservedBindingKey` (`Adapter8004.sol:101`, `281–289`); `setMetadata` direct check (`132–134`); `setMetadataBatch` via the same scan (`145`) | ✅ all three write paths blocked |
| L96: agent-binding MUST be written at registration | `Adapter8004.sol:110` (step 6 of `register`) | ✅ written every register |

### Specific lines you asked me to confirm

- **`Adapter8004.sol:159` — `return abi.encodePacked(bindingContract);`**
  Matches spec L77 verbatim and the example payload at L83/L120. Output is exactly 20 bytes. **Still compliant with v2026-04-05; no drift.**

- **`Adapter8004.sol:178` — `function bindingOf(uint256 agentId) external view returns (Binding memory)`**
  Matches spec L58 selector and return shape. The local `Binding`/`TokenStandard` types are ABI-equivalent to the spec's `IERCAgentBindings.Binding` / `IERCAgentBindings.TokenStandard`. **Still compliant.** The only nit is type identity (see §2 item 1) — the function is shape-correct and decodes correctly through the spec interface.

---

## 2. Drift / gaps (spec items not yet implemented as written)

These are real gaps against the v2026-04-05 text, ordered by severity:

1. **No declared `IERCAgentBindings` interface in source.** Spec §"Simplified Interface" (L34–60) says compliant adapters "MUST expose" `IERCAgentBindings`. The adapter exposes a duck-typed match (same selector, same struct ABI), but:
   - There is no `src/interfaces/IERCAgentBindings.sol`.
   - `Adapter8004` does not `is IERCAgentBindings` and the enum/struct are inlined under the `Adapter8004` namespace (`Adapter8004.TokenStandard`, `Adapter8004.Binding`).
   - External integrators that import the spec interface will still get correct ABI decoding, but Solidity-level type sharing is missing and the conformance is implicit.
   - **Action:** add `src/interfaces/IERCAgentBindings.sol` with the exact code from spec L42–60, make `Adapter8004 is …, IERCAgentBindings`, and have `bindingOf` return `IERCAgentBindings.Binding memory`.

2. **No ERC-165 advertisement of the binding interface.**
   Spec is silent on ERC-165 (it is *not* required), but flagging because once `IERCAgentBindings` exists, exposing `supportsInterface(type(IERCAgentBindings).interfaceId)` is the standard discovery pattern and costs little. **Optional, not required by v2026-04-05.**

3. **`bindingOf` reverts on unknown agent (`Adapter8004.sol:184` → `UnknownAgent(agentId)`).**
   Spec L111 says: *"If any step fails, clients MUST treat the binding relationship as unverified."* A revert is one valid failure mode under that rule, so this is **compliant** (clients catching the revert satisfy L111). Listed here only because some verifiers may prefer a soft return; not a drift.

4. **`encodeBindingMetadata` exposed as a public helper (`Adapter8004.sol:158`).**
   Not in the spec interface and not required. Harmless and helpful for tests. **Compliant**, just noting it is adapter-specific surface area outside the standard.

5. **Reserved-key enforcement scope.**
   Spec L98 + L170: "untrusted callers cannot overwrite or forge the canonical record after registration." The adapter blocks the three caller-facing write paths, but the underlying `IERC8004IdentityRegistry.setMetadata` (`IERC8004IdentityRegistry.sol:12`) is not adapter-only at the registry level. ERC-8217 reserves the *adapter's* enforcement, and it does enforce — **compliant**. If the registry permits other writers (e.g., the registry's own `ownerOf` mechanism) to write `agent-binding`, that is a registry-side concern, not an adapter-side ERC-8217 gap. Worth a one-line comment in the adapter's NatSpec.

---

## 3. Tests — what already proves the spec, what is missing

### Already covered

- `test/Adapter8004.t.sol:175–180` (`testEncodeBindingMetadataIsTwentyByteAddress`) — payload length 20 and byte-for-byte equality with `abi.encodePacked(addr)`. Directly proves spec L74–78.
- `test/Adapter8004.t.sol:80–82` — checks `registry.getMetadata(agentId, "agent-binding") == encodeBindingMetadata(address(adapter))` post-`register`. Proves spec L96 + L88 (stored address is the adapter that serves `bindingOf`).
- `test/Adapter8004.t.sol:182–219` — three reserved-key tests (`register`, `setMetadata`, `setMetadataBatch`). Proves spec L98.
- `test/security/Adapter8004.invariants.t.sol:99–111` (`testFuzzCanonicalBindingMetadataMatchesEncoder`) — fuzzed proof that `stored.length == 20` and `stored == encodeBindingMetadata(address(adapter))` under random holders/tokenIds. Strong invariant on spec L72–78.
- `test/security/Adapter8004.invariants.t.sol:60–92` (`bindingOf` byte-for-byte unchanged after non-binding writes) — protects spec L90 (only `bindingOf` is canonical for token info).

### Missing / recommended additions

These do not block compliance but are warranted to lock the spec down:

- **End-to-end verifier-flow test (spec L105–109).** Read `agent-binding` metadata, parse the 20 bytes into an `address` (e.g., `abi.decode(abi.encodePacked(bytes12(0), stored), (address))` or assembly load + shift-right by 96), then call `IERCAgentBindings(parsed).bindingOf(agentId)` and assert the returned struct matches what `register` recorded. Currently no test exercises the parse-and-call round trip.
- **Type-level conformance test.** Once `IERCAgentBindings` exists, add a test that does `IERCAgentBindings b = IERCAgentBindings(address(adapter)); Binding memory got = b.bindingOf(agentId);` to fail-fast on any future struct/enum drift.
- **Length-not-20 negative test for clients (defensive).** Optional: if the adapter ever exposes a write helper for `agent-binding` (it currently does not), assert the encoder rejects non-20-byte writes. Today the only writer is `register`, which uses the encoder — so this is purely defensive against future code.

---

## 4. Interface file (`IERC8004IdentityRegistry.sol`) — what to adjust

This file is the ERC-8004 registry interface, not ERC-8217. It is **not** affected by ERC-8217 v2026-04-05 changes — ERC-8217 only requires the metadata key/value contract on the registry's existing `getMetadata`/`setMetadata` surface, which `IERC8004IdentityRegistry` already exposes (`IERC8004IdentityRegistry.sol:12`, `:20`).

The new file to add is `src/interfaces/IERCAgentBindings.sol` (see §2 item 1). No change to `IERC8004IdentityRegistry.sol` is required for ERC-8217 compliance.

---

## 5. Bottom line

- **Wire-format compliance: full.** The 20-byte `abi.encodePacked(bindingContract)` payload, the `agent-binding` key, the `bindingOf(uint256) returns (Binding)` signature, the `TokenStandard` enum order, and the reserved-key enforcement all match v2026-04-05 exactly. Lines `Adapter8004.sol:159` and `Adapter8004.sol:178` specifically still match the latest spec.
- **Type-level / declarative compliance: partial.** Adapter does not declare or inherit `IERCAgentBindings`; the conformance is structural rather than nominal.
- **Test coverage: solid for the payload invariant, missing the verifier round-trip.**

Recommended minimal change set to close all v2026-04-05 gaps (no edits performed per request):
1. Add `src/interfaces/IERCAgentBindings.sol` (verbatim from spec L42–60).
2. Make `Adapter8004 is IERCAgentBindings`; reuse its `Binding`/`TokenStandard` types.
3. Add a verifier-flow test that parses the 20 bytes back to an address and calls `bindingOf` through the spec interface.
4. (Optional, not spec-required) `supportsInterface(type(IERCAgentBindings).interfaceId)`.
