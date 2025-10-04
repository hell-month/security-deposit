#!/bin/bash

# Check if .env exists and source it
if [ -f ".env" ]; then
    source .env
else
    echo "Please create .env file with required variables"
    exit 1
fi

# Required env vars check
if [ -z "$DEPLOYER_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Missing required environment variables. Please ensure you have:"
    echo "RPC_URL - RPC URL for the Ethereum network"
    exit 1
fi

echo "Deploying to Ethereum Mainnet..."

forge script script/mainnet/Slash.s.sol:SlashScript \
    --slow \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --verify \
    --ledger \
    --sender "$DEPLOYER_ADDRESS" \
    --mnemonic-indexes 1 \
    -vvvv

if [ $? -eq 0 ]; then
    echo "✅ Deployment completed!"
    echo "Check the logs above for contract addresses"
else
    echo "❌ Deployment failed"
    exit 1
fi
