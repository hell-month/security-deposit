#!/bin/bash

# Check if .env exists and source it
if [ -f ".env" ]; then
    source .env
else
    echo "Please create .env file with required variables"
    exit 1
fi

# Required env vars check
if [ -z "$DEPLOYER_ADDRESS" ] || [ -z "$ETHERSCAN_API_KEY" ] || [ -z "$RPC_URL" ]; then
    echo "Missing required environment variables. Please ensure you have:"
    echo "DEPLOYER_ADDRESS - Deployer's Ethereum address"
    echo "ETHERSCAN_API_KEY - API key for verification"
    echo "RPC_URL - RPC URL for the Ethereum network"
    exit 1
fi

echo "Deploying to Ethereum Mainnet..."

forge script script/mainnet/SecurityDepositPool.s.sol:SecurityDepositPoolScript \
    --slow \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --verify \
    --ledger \
    --sender "$DEPLOYER_ADDRESS" \
    --verifier etherscan \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    --mnemonic-indexes 1 \
    -vvvv

if [ $? -eq 0 ]; then
    echo "✅ Deployment completed!"
    echo "Check the logs above for contract addresses"
else
    echo "❌ Deployment failed"
    exit 1
fi
