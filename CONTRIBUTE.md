# Contributing to the Aelin Solidity Contracts

## devDAO

Aelin is a permissionless multi-chain protocol for capital raises and OTC deals. Through Aelin, protocols can use their communities to access funding. We are community-driven and welcome all contributions. Our goal is to provide a constructive, respectful, and enjoyable environment for collaboration. If you'd like to help out, join the Aelin devDAO on our #TBD Discord channel.

## Introduction

In order to maintain a simple and straightforward process for contributing to the Aelin solidity contracts, this document serves to establish standards and guidelines for the structure of the codebase and the interaction between various components. By adhering to these guidelines, devDAO contributors can ensure consistency and coherence throughout the project, facilitating collaboration and making it easier to maintain and scale the UI.

## How to contribute?

We operate as any other open source project, you will find our Issues and Pull Requests in our Github repository. We use Discord to chat and distribute tickets to community members.

### Issues Assignment

To ensure alignment between Aelin's objectives and the developers who wish to contribute to the project through the devDAO, Core Contributors will be responsible for creating Github issues. These issues will be labeled with the `devdao` badge for easy recognition. The ticket assignments will be handled in Discord, so it is important to check there before beginning work on an issue to avoid duplication of effort. This will help to maximize efficiency and prevent any unnecessary overlap in contributions.

### Pull Request Review Process

Aelin CCs will review pull requests submitted by devDAO contributors and provide feedback on what each CC believes is best to ensure the scalability and stability of the project. It is desirable that if you have any questions about how to think of a new solution, ask the CCs, they will give you enough insight to help you take the right direction. Once a PR is merged, a reward will be sent to you for helping to improve the Aelin UI.

### Issues Bounty

Once a pull request is merged, a bounty will be attached to the associated issue. To ensure that you have the opportunity to earn the bounty, it's crucial that you participate in the developer pick process on Discord. If you submit a pull request without having been selected for the associated task, your PR will not receive a reward. Of course, it's no problem if you want to contribute on your own, but it is desirable to participate through devDAO.

## Technical Details

### Requirements

To start developing, it is recommended that you have a Node.js version manager installed in order to install the LTS version. One of the package managers that you can use is "n" (https://www.npmjs.com/package/n). We recommend following the instructions on its GitHub page to install "n" based on your operating system. Once you have installed `n`, you can run the command `n lts` to install the latest stable version of Node.js.

### First-time Set-up

First-time contributors can get their git environment up and running with these steps:

1- Create a fork and clone it to your local machine.

2- Add an "upstream" branch that tracks the Aelin repository using $ git remote add upstream https://github.com/AelinXYZ/aelin.git (pro-tip: use SSH instead of HTTPS).

3- Create a new Issue (feature or bug). Take note of the issue number.

3- Create a new feature branch with `$ git checkout -b feature|bug/#issue_branch_name`. The name of your branch isn't critical but it should be short and instructive. We recommend to use the git flow approach

4- Make sure you sign your commits. See the relevant doc.
Commit your changes and push them to your fork with `$ git push origin your_feature_name`

5- [`TESTING IS MANDATORY`] All your changes must be properly tested, otherwise your PR wont be reviewed.
[Please follow foundry's best practices](https://book.getfoundry.sh/tutorials/best-practices).

### How to run the project?

Please use forge to install all dependencies.
To get started, the first thing you'll need to do is clone the project. After that's done you can install all dependencies by running `npm install`.

### Testing

- Test all

```
forge test
```

- Match an specific test file

```
forge test --match-contract [name of your test contract]
```

- Match an specific test

```
forge test --match-contract [name of your test contract] --match-test [name of your test]
```

### Contract deployment

We recommend to use `foundry` for contract deployment. In case you want to deploy an specific contract to a network of your choice, run the following command:\
`forge create --rpc-url [NETWORK_RPC] --private-key [WALLET_PK] contracts/[Contract].sol:[Contract]`

> Keep in mind that some contracts have other contracts as dependencies, so deployment order is important. Also the configuration file `foundry.toml` needs to be updated accordingly.

In case you want to deploy all contracts, you'll have to follow these steps:

1. Using the command shown above, deploy the following contracts (no specific order):

```
AelinFeeEscrow
MerkleTree
AelinAllowList
AelinNftGating
NftCheck
AelinDeal
AelinPool
```

2. Update the file `foundry.toml` appending:

```
   libraries = [
   "contracts/libraries/MerkleTree.sol:MerkleTree:[DEPLOYED_ADDRESS_FROM_1]",
   "contracts/libraries/AelinAllowList.sol:AelinAllowList:[DEPLOYED_ADDRESS_FROM_1]",
   "contracts/libraries/AelinNftGating.sol:AelinNftGating:[DEPLOYED_ADDRESS_FROM_1]"
   ]
```

3. Deploy `AelinUpFrontDeal`:

```
forge create --rpc-url [NETWORK_RPC] --private-key [WALLET_PK] contracts/AelinUpFrontDeal.sol:AelinUpFrontDeal
```

4. Deploy `AelinUpFrontDealFactory`

```
forge create --rpc-url [NETWORK_RPC] --private-key [WALLET_PK] contracts/AelinUpFrontDealFactory.sol:AelinUpFrontDealFactory --constructor-args [DEPLOYED_AelinUpFrontDeal_ADDRESS] [DEPLOYED_AelinFeeEscrow_ADDRESS] [TREASURY_ADDRESS]
```

5. Deploy `AelinPoolFactory`

```
forge create --rpc-url [NETWORK_RPC] --private-key [WALLET_PK] contracts/AelinPoolFactory.sol:AelinPoolFactory --constructor-args [DEPLOYED_AelinPool_ADDRESS] [DEPLOYED_AelinDeal_ADDRESS] [TREASURY_ADDRESS] [DEPLOYED_AelinFeeEscrow_ADDRESS]
```

You can also deploy and test your changes `locally` by following these [steps](https://github.com/AelinXYZ/aelin-frontend-v2#testing.md)
