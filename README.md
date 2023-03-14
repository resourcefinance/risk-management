```
   _____       _____
  |  __ \     / ____|
  | |__) |___| (___   ___  _   _ _ __ ___ ___
  |  _  // _ \\___ \ / _ \| | | | '__/ __/ _ \
  | | \ \  __/____) | (_) | |_| | | | (_|  __/
  |_|  \_\___|_____/ \___/ \__,_|_|  \___\___|
```

# ⚠️ ReSource Risk Management

The following decentralized infrastructure is responsible for providing **Credit Networks** with the means to analyze, predict, and mitigate credit risk within a mutual credit context.

Risk can be thought of in two categories: **network wide risk** and **member specific risk.**

####Network Risk
Network risk is addressed via a **Risk Oracle** infrastructure that is responsible for monitoring and analyzing network risks in order to calculate a given network's _risk variables_. These variables include the price of risk (the network's "base fee") as well as the required reserve size (the network's "RTD") needed to safely maintain stability.

The **Risk Oracle** infrastructure is federated by a network registry that determines if a network's risk is being indexed and analyzed. The risk analysis provided by the **_RiskOracle.sol_** is then used by the **_RiskManager.sol_** contract to translate analyzed risk into the network _risk variables_.

####Member Risk
Member risk is addressed through effective underwriting and proper credit term structuring and assignment. The **_CreditIssuer.sol_** contract is responsible for defining and issuing the credit terms (ex. credit limit, fee rate) associated with a given network to be tracked over a configured _credit period_.

📕 For more information on ReSource Risk Mitigation go to the [docs](https://docs.stablecredit.io/stable-credit/credit-risk).

## Protocol Overview

---

The following diagram depicts how **Stable Credit** networks interact with the **ReSource Risk Management** protocol to stabilize their credit currencies.
![alt text](./Diagram.png)

---

## Contracts:

- **`ReservePool.sol`**: Responsible for storing and transferring network reference tokens in order to back the credit currency.
- **`ReserveRegistry.sol`**: Responsible for maintaining a list of reserves that are to be analyzed and maintained by the ReSource Risk Management infrastructure.
- **`RiskOracle.sol`**: Responsible for exposing calculated network risk data.

# 🏄‍♂️ Quick Start

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework and [Hardhat](https://github.com/NomicFoundation/hardhat) for the deployment framework.

#### Dependencies

```
yarn install
```

```bash
forge install
```

#### Compilation

```bash
forge build
```

#### Testing

```bash
forge test
```

#### Deploy

```bash
yarn deploy
```
