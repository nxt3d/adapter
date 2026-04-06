#!/usr/bin/env bash
set -euo pipefail

# 1. Require a supported target network name.
NETWORK="${1:-}"
if [[ -z "$NETWORK" ]]; then
  echo "usage: script/deploy.sh [base|mainnet|sepolia]"
  exit 1
fi

# 2. Load local deployment configuration from .env when present.
if [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source ".env"
fi

# 3. Map the requested network to its RPC URL and ERC-8004 registry env vars.
case "$NETWORK" in
  base)
    RPC_URL="${BASE_RPC_URL:-}"
    IDENTITY_REGISTRY_ADDRESS="${BASE_IDENTITY_REGISTRY_ADDRESS:-}"
    ;;
  mainnet)
    RPC_URL="${MAINNET_RPC_URL:-}"
    IDENTITY_REGISTRY_ADDRESS="${MAINNET_IDENTITY_REGISTRY_ADDRESS:-}"
    ;;
  sepolia)
    RPC_URL="${SEPOLIA_RPC_URL:-}"
    IDENTITY_REGISTRY_ADDRESS="${SEPOLIA_IDENTITY_REGISTRY_ADDRESS:-}"
    ;;
  *)
    echo "unsupported network: $NETWORK"
    echo "supported networks: base, mainnet, sepolia"
    exit 1
    ;;
esac

# 4. Refuse to run without the required deployment configuration.
if [[ -z "${DEPLOYER_PRIVATE_KEY:-}" ]]; then
  echo "missing DEPLOYER_PRIVATE_KEY in environment"
  exit 1
fi

if [[ -z "$RPC_URL" ]]; then
  echo "missing RPC URL for network: $NETWORK"
  exit 1
fi

if [[ -z "$IDENTITY_REGISTRY_ADDRESS" ]]; then
  echo "missing identity registry address for network: $NETWORK"
  exit 1
fi

# 5. Export the exact env vars the Foundry deployment script expects.
export DEPLOYER_PRIVATE_KEY
export IDENTITY_REGISTRY_ADDRESS

# 6. Broadcast the adapter implementation and proxy deployment to the selected chain.
forge script script/DeployAdapter.s.sol:DeployAdapterScript --rpc-url "$RPC_URL" --broadcast
