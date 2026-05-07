# ERC-8004 Interop Review: Response to @wscdcm

**PR:** https://github.com/ethereum/ERCs/pull/1648 (ERC-8217: Agent NFT Identity Bindings)
**Comment under review:** 4300173925
**Their contract:** `0xc0D37E6F7B214C92f292FC0534195027CD38AB79` on Sepolia (`ERC8004IdentityV2`)
**Our contract:** `Adapter8004` proxy on mainnet/Base/Sepolia
**Author of this analysis:** nxt3d (for internal review, not yet posted)

## 1. Summary of the critique

@wscdcm argues that:

1. Their `ERC8004IdentityV2` exposes a domain-specific API (`createIdentity`, `addCapability`, `updateTrustLevel`, `setEndpoint`, single `metadataURI` per token).
2. Our `Adapter8004` expects a generic key-value metadata API (`register`, `setMetadata`, `getMetadata`, `setAgentWallet`).
3. This divergence breaks ERC-8217's `bindingOf()` verification flow, which requires reading the `agent-binding` entry from the identity registry.
4. Therefore ERC-8004 should mandate a minimum metadata interface:

```solidity
interface IERC8004Metadata {
    function getMetadata(uint256 agentId, string calldata key) external view returns (bytes memory);
    function setMetadata(uint256 agentId, string calldata key, bytes calldata value) external;
}
```

## 2. What the Adapter actually expects

`src/interfaces/IERC8004IdentityRegistry.sol` declares, among others:

- `function register(string memory agentURI, MetadataEntry[] memory metadata) external returns (uint256)`
- `function setMetadata(uint256 agentId, string memory metadataKey, bytes memory metadataValue) external`
- `function getMetadata(uint256 agentId, string memory metadataKey) external view returns (bytes memory)`
- `function setAgentURI(uint256 agentId, string calldata newURI) external`
- `function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata signature) external`
- `function unsetAgentWallet(uint256 agentId) external`
- `function getAgentWallet(uint256 agentId) external view returns (address)`
- `function ownerOf(uint256 agentId) external view returns (address)`
- `function tokenURI(uint256 agentId) external view returns (string memory)`

Relevant usage in `src/Adapter8004.sol`:

- `register` forwards to `identityRegistry.register(agentURI, metadata)` (line 104).
- `register` writes the canonical binding bytes via `identityRegistry.setMetadata(agentId, BINDING_METADATA_KEY, encodeBindingMetadata(...))` where `BINDING_METADATA_KEY = "agent-binding"` (lines 14, 110-112).
- `register` clears the default wallet via `identityRegistry.unsetAgentWallet(agentId)` (line 115).
- `setAgentWallet` / `unsetAgentWallet` are pass-through wrappers (lines 174-188).
- `setMetadata` / `setMetadataBatch` forward per-key writes after guarding the reserved `agent-binding` key (lines 129-157).
- `bindingOf(uint256)` returns the stored `Binding` struct for ERC-8217 verification (lines 190-201).

## 3. What ERC-8004 actually says

The current ERC-8004 draft (tracked locally at `lib/erc-8004-contracts/ERC8004SPEC.md`, and matching the public EIP draft) normatively specifies the Identity Registry as ERC-721 with URIStorage, plus an on-chain key-value metadata extension:

> The registry extends ERC-721 by adding `getMetadata(uint256 agentId, string metadataKey)` and `setMetadata(uint256 agentId, string metadataKey, bytes metadataValue)` functions for optional extra on-chain agent metadata.

The draft also explicitly specifies the following register overloads:

```solidity
function register(string agentURI, MetadataEntry[] calldata metadata) external returns (uint256 agentId);
function register(string agentURI) external returns (uint256 agentId);
function register() external returns (uint256 agentId);
```

And the reserved `agentWallet` key with:

```solidity
function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes calldata signature) external;
function getAgentWallet(uint256 agentId) external view returns (address);
function unsetAgentWallet(uint256 agentId) external;
```

**Observation:** the `IERC8004Metadata` interface @wscdcm proposes (`setMetadata` / `getMetadata` with `(uint256 agentId, string key, bytes value)`) is already mandated by the current ERC-8004 draft, with the exact same signature. The Adapter's `IERC8004IdentityRegistry` is built against that draft and does not diverge from it.

## 4. What `ERC8004IdentityV2` actually exposes

Verified against the verified source at https://sepolia.etherscan.io/address/0xc0D37E6F7B214C92f292FC0534195027CD38AB79#code:

- `createIdentity(string metadataURI) -> uint256`
- `batchCreateIdentities(address[], string[]) -> uint256[]`
- `updateMetadata(uint256 tokenId, string newMetadataURI)`
- `addCapability(uint256 tokenId, string name, bytes32 capabilityHash)`
- `removeCapability(uint256 tokenId, bytes32 capabilityHash)`
- `getCapabilities(uint256 tokenId) -> AgentCapability[]`
- `updateTrustLevel(uint256 tokenId, uint8 newLevel)`
- `deactivateIdentity(uint256 tokenId)` / `reactivateIdentity(uint256 tokenId)`
- `setVault(address)`
- Standard ERC-721 surface

Not present:

- `register(string, MetadataEntry[])`
- `setMetadata(uint256, string, bytes)`
- `getMetadata(uint256, string) -> bytes`
- `setAgentWallet` / `getAgentWallet` / `unsetAgentWallet`
- `setAgentURI`

`V2` stores metadata only as a single `metadataURI` string per token, updated via `updateMetadata(tokenId, newMetadataURI)`. There is no on-chain key-value metadata surface at all, and no reserved `agentWallet` concept.

## 5. Assessment

1. The divergence is real but in the opposite direction from what the comment implies. `Adapter8004` follows the ERC-8004 draft. `ERC8004IdentityV2` does not implement the on-chain key-value metadata functions that ERC-8004 requires, and it replaces the `agentWallet` mechanism with an unrelated `setVault` function.
2. Does `V2` break ERC-8217 `bindingOf()` verification? Yes, but the proximate cause is that it does not expose `getMetadata(agentId, "agent-binding")`. Any ERC-8217 verifier would also fail against `V2` regardless of whether our Adapter is involved, because the canonical `agent-binding` bytes can only be written and read through the key-value surface.
3. Is the proposed `IERC8004Metadata` reasonable? Yes, but it is a subset of what ERC-8004 already mandates, so the right outcome is not a new interface. The right outcomes are: (a) have ERC-8217 cite the relevant ERC-8004 section as a prerequisite so implementers do not miss it, and (b) have `V2` (or any successor) add the missing functions to become ERC-8004 conforming.
4. The Adapter does not need code changes. Its interface, binding encoding, and reserved-key guard are all aligned with the current ERC-8004 draft and with the ERC-8217 binding discovery flow.

## 6. Recommendation

**Option (b), said charitably, with a constructive spec nudge.**

- Clarify publicly that the current ERC-8004 draft already specifies `setMetadata` / `getMetadata` with exactly the signature @wscdcm proposes, so the Adapter is conforming and no new interface is needed at the ERC-8004 level.
- Acknowledge the underlying interoperability concern is legitimate: ERC-8217 `bindingOf()` discovery depends on the key-value surface, and that dependency should be made explicit in the ERC-8217 text so future implementers do not reach for a URI-only metadata model.
- Offer a path forward for `V2`: add `setMetadata(uint256, string, bytes)` / `getMetadata(uint256, string)` (and optionally the `register(string, MetadataEntry[])` overload and the `agentWallet` functions) and the Adapter will work against it without changes.
- No Adapter code changes. Optional, non-urgent follow-up: a separate compatibility shim contract could wrap `V2`'s `createIdentity` / `updateMetadata` and expose `register(string, MetadataEntry[])` / `setMetadata(uint256, string, bytes)` / `getMetadata(uint256, string)` for registries that want to bridge to ERC-8004 without redeploying. We do not need to ship this unless a real integrator requests it.

## 7. Draft public reply (under 400 words)

> Thanks for running this interop test and publishing the write-up. A few clarifications so readers of the PR have an accurate picture.
>
> The current ERC-8004 draft already specifies the on-chain key-value metadata surface that `Adapter8004` relies on. The "On-chain metadata" section mandates:
>
> ```solidity
> function getMetadata(uint256 agentId, string metadataKey) external view returns (bytes memory);
> function setMetadata(uint256 agentId, string metadataKey, bytes metadataValue) external;
> ```
>
> and the Registration section specifies the `register(string agentURI, MetadataEntry[] metadata)` overload and the reserved `agentWallet` key with `setAgentWallet` / `getAgentWallet` / `unsetAgentWallet`. The `IERC8004IdentityRegistry` the Adapter imports is built directly against those signatures, and that is why `ERC-8217` `bindingOf()` verification assumes the same surface: it reads `agent-binding` via `getMetadata(agentId, "agent-binding")`.
>
> Looking at the verified source for `ERC8004IdentityV2` on Sepolia, the contract exposes `createIdentity`, `updateMetadata(tokenId, metadataURI)`, `addCapability`, `updateTrustLevel`, and `setVault`, but does not expose `setMetadata(uint256, string, bytes)`, `getMetadata(uint256, string)`, `setAgentWallet`, `unsetAgentWallet`, or `getAgentWallet`. Metadata is held as a single URI string. That is a valid design, but it is a different specification from the current ERC-8004 draft, which means an ERC-8217 verifier cannot read `agent-binding` from it. The issue is not that the Adapter expects an unusual interface; it is that `V2` does not implement the ERC-8004 on-chain metadata surface at all.
>
> On your `IERC8004Metadata` proposal: the two functions you list are exactly what the current ERC-8004 draft already requires, so the right fix is probably not a new minimum interface but a clearer pointer inside ERC-8217 that it depends on that specific part of ERC-8004. I am happy to add language to that effect in the next push of this PR.
>
> If you want `V2` to interoperate with `bindingOf()` today, adding the two metadata functions (and ideally the `register(string, MetadataEntry[])` overload plus the `agentWallet` functions) is enough. The Adapter will work against any registry that exposes them, no changes required on our side.

---

## 8. Artifact provenance

- Adapter surface read from `src/Adapter8004.sol` and `src/interfaces/IERC8004IdentityRegistry.sol` at working tree HEAD on 2026-04-24.
- ERC-8004 normative text read from `lib/erc-8004-contracts/ERC8004SPEC.md` (vendored copy of the EIP draft).
- `ERC8004IdentityV2` surface confirmed via Etherscan Sepolia verified source listing.
- Analyzed within the 45-minute budget. No contract or spec edits performed. No posting to GitHub.
