# security-deposit

Security deposit pool for Hell Month.

## Tests information

Coverage is 100%.

![tests and coverage](coverage.png)

If you find any critical vulnerabilities involving theft or loss of funds, please message [@joelmun](https://t.me/joelmun).

## Assumptions

- `fundsManager` is a trusted address chosen by the deployer.
- USDT contract is trusted to be fully functional without any vulnerabilities, which means a reentrancy attack using it is impossible.

## Deployments

### Base Sepolia Testnet

- MockUSDT: https://sepolia.basescan.org/address/0xc48132a50d54f7edb81bf8d4831972ee2719993e
- SecurityDepositPool: https://sepolia.basescan.org/address/0x26fa848bc68761b46281b65c399e45bfe1b863c8
