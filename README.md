# security-deposit

Security deposit pool for Hell Month.

## Tests information

Coverage is 100%.

![tests and coverage](coverage.png)

If you find any critical vulnerabilities involving theft or loss of funds, please message [@joelmun](https://t.me/joelmun).

## Assumptions

- `fundsManager` is a trusted address chosen by the deployer.
- USDC contract is trusted to be fully functional without any vulnerabilities, which means a reentrancy attack using it is impossible.