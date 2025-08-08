#!/bin/bash

# Check if .env exists and source it
if [ -f ".env.testnet.ledger" ]; then
    source .env.testnet.ledger
else
    echo "Please create .env file with required variables"
    exit 1
fi

# Required env vars check
if [ -z "$DEPLOYER_ADDRESS" ] || [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Missing required environment variables. Please ensure you have:"
    echo "DEPLOYER_ADDRESS - Your wallet address"
    echo "ETHERSCAN_API_KEY - API key for verification"
    exit 1
fi

echo "Deploying to Base Sepolia Testnet..."

# Deploy using forge script
# Connect Ledger to the computer, close the Ledger desktop app, and leave Ethereum app on Ledger open
# 
# --mnemonic-indexes 1 is used to specify the Ledger account index. 
# May need to change based on your setup.
forge script script/testnet/SecurityDepositPool.s.sol:SecurityDepositPoolScript \
    --slow \
    --rpc-url "https://sepolia.base.org" \
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
