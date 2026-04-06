# Adapter8004 Deployment Report - 2026-04-05

## Summary

Deployer:

- `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

ERC-8004 IdentityRegistry addresses:

- Ethereum mainnet (`chainId = 1`): `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
- Base (`chainId = 8453`): `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
- Sepolia (`chainId = 11155111`): `0x8004A818BFB912233c491871b3d84c89A494BD9e`

This report supersedes the earlier mainnet and Base deployments that incorrectly pointed at the Sepolia registry address.

## Sepolia

- Chain ID: `11155111`
- IdentityRegistry: `0x8004A818BFB912233c491871b3d84c89A494BD9e`
- Adapter implementation: `0x5Ced539aE5Fe67183a2bA4E984F92D57dFB3bd49`
- Adapter proxy: `0x7621630cB63a73a194f45A3E6801B8C6A7eC2f92`
- Implementation deployment tx: `0xcaf18c89a94e1b20410b0d94b9793c6440cc9ca8411c19c4e3c6b1cdc598eaba`
- Proxy deployment tx: `0xe81ae855a99c2b16642691409924098b996ec1e6a6e1da0b6d8378c0679d659d`
- Proxy owner/admin: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- Broadcast artifact: [`broadcast/DeployAdapter.s.sol/11155111/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/DeployAdapter.s.sol/11155111/run-latest.json)

## Base

- Chain ID: `8453`
- IdentityRegistry: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
- Adapter implementation: `0x9DB9d78E1BB45604Fbfe30FaE123B152FA10de2d`
- Adapter proxy: `0x270d25D2c59A8bcA1B0f40ad95fF7806c0025c27`
- Implementation deployment tx: `0x5bd9e2dc4e07144a75e5ee6673605bebaebf22e9c48d785a1a9762899b2180a1`
- Proxy deployment tx: `0xe79d065dc2e83848e6c9a38e31f4fa3ec4062382cf86b62a21a47a0156aeabc6`
- Proxy owner/admin: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- Broadcast artifact: [`broadcast/DeployAdapter.s.sol/8453/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/DeployAdapter.s.sol/8453/run-latest.json)

Superseded Base deployment:

- Proxy: `0xD83A132Df91869452d358Eba6C54DcA827c83498`
- Reason: initialized with the Sepolia `IdentityRegistry` address instead of the Base mainnet address

## Ethereum Mainnet

- Chain ID: `1`
- IdentityRegistry: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
- Adapter implementation: `0xA54a604448A5Ab0AfFccdDa6228EC4F2ac12a586`
- Adapter proxy: `0xde152AfB7db5373F34876E1499fbD893A82dD336`
- Implementation deployment tx: `0x6e3ab0844e521f77da8220849bbfe2df411c8ed93a1f6f532a8acda13060d61a`
- Proxy deployment tx: `0xf4d34051b0bba198c8147c55bcc849517f5ba92a1b2ce25248c05d55b15bf519`
- Proxy owner/admin: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- Broadcast artifact: [`broadcast/DeployAdapter.s.sol/1/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/DeployAdapter.s.sol/1/run-latest.json)

Superseded Ethereum mainnet deployment:

- Proxy: `0xC38570C2c356E98fF4d07E4Be164307D8A4AB556`
- Reason: initialized with the Sepolia `IdentityRegistry` address instead of the Ethereum mainnet address

## Notes

- The deployer key was used as the adapter admin during initialization.
- Each deployment created a fresh implementation contract and a fresh `ERC1967Proxy`.
- The adapter proxy is the address users and integrators should interact with.
