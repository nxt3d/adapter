# Adapter8004 Deployment Report - 2026-04-05

## Summary

Deployer:

- `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

ERC-8004 IdentityRegistry used on all deployed chains:

- `0x8004A818BFB912233c491871b3d84c89A494BD9e`

This registry address was verified to have deployed code on:

- Ethereum mainnet (`chainId = 1`)
- Base (`chainId = 8453`)
- Sepolia (`chainId = 11155111`)

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
- IdentityRegistry: `0x8004A818BFB912233c491871b3d84c89A494BD9e`
- Adapter implementation: `0xF2bFc17D87a774c32C6e950640db8A34AF758981`
- Adapter proxy: `0xD83A132Df91869452d358Eba6C54DcA827c83498`
- Implementation deployment tx: `0xa390f51774e21174e6b291c8ad0502a6775d4075e0ce8afa3b98393e1e5fe67d`
- Proxy deployment tx: `0x1f944bf35adb7031ce7ae3eb0083186f87be7935ca63ed9944b780e2b56ca73b`
- Proxy owner/admin: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- Broadcast artifact: [`broadcast/DeployAdapter.s.sol/8453/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/DeployAdapter.s.sol/8453/run-latest.json)

## Ethereum Mainnet

- Chain ID: `1`
- IdentityRegistry: `0x8004A818BFB912233c491871b3d84c89A494BD9e`
- Adapter implementation: `0x4fF37d9C22f40726F39429677aE2537153803d52`
- Adapter proxy: `0xC38570C2c356E98fF4d07E4Be164307D8A4AB556`
- Implementation deployment tx: `0x1fc39a3fa5eef70611c91c40fe32b538579c755ea3a7b94888aaa6b81744337c`
- Proxy deployment tx: `0x12021de366801fb92656995cb8f2b47f39a9f03de61f8a5260800c48db9353a1`
- Proxy owner/admin: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- Broadcast artifact: [`broadcast/DeployAdapter.s.sol/1/run-latest.json`](/Users/nxt3d/projects/adapter/broadcast/DeployAdapter.s.sol/1/run-latest.json)

## Notes

- The deployer key was used as the adapter admin during initialization.
- Each deployment created a fresh implementation contract and a fresh `ERC1967Proxy`.
- The adapter proxy is the address users and integrators should interact with.
