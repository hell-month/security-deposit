#!/bin/bash

# Check if .env exists and source it
if [ -f ".env.testnet" ]; then
    source .env.testnet
else
    echo "Please create .env file with required variables"
    exit 1
fi

# Required env vars check
if [ -z "$DEPLOYER_PK" ] || [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Missing required environment variables. Please ensure you have:"
    echo "DEPLOYER_PK - Your wallet private key"
    echo "ETHERSCAN_API_KEY - API key for verification"
    exit 1
fi

echo "Deploying to Base Sepolia Testnet..."

# Deploy using forge script
# https://aeneid.storyrpc.io
# https://rpc.ankr.com/story_aeneid_testnet
forge script script/testnet/SecurityDepositPool.s.sol:SecurityDepositPoolScript \
    --slow \
    --rpc-url "https://sepolia.base.org" \
    --private-key "$DEPLOYER_PK" \
    --broadcast \
    --verify \
    --verifier etherscan \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    -vvvv

if [ $? -eq 0 ]; then
    echo "✅ Deployment completed!"
    echo "Check the logs above for contract addresses"
else
    echo "❌ Deployment failed"
    exit 1
fi
