# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```

---

## Blind Market Test Scenario

### Success Case Scenario

#### Set approve contract

#### Set user information

#### Seller post product

#### Buyer made request for product

#### Seller send product to buyer

##### Case 1 : Seller did not use BLIND token

##### Case 2 : Seller use BLIND token

#### Buyer receive product and finish the trade phase.

> Checkpoint
>
> 1. Did grade point updated?
> 2. Did NFT token for product transferred to buyer?
> 3. Did fee payment properly completed?
> 4. Did price payment properly completed?
> 5. Did user grade properly updated?

---

### Cancel Case Scenario

#### Set approve contract

#### Set user information

#### Seller post product

#### Buyer made request for product

#### Buyer cancle request

> Checkpoint
>
> 1. Did request canceled properly?
> 2. Did NFT Token unlocked?
