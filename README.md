# Yen Stable Coin

## About
This solidity code is based on the Stablecoin contract tutorial in the Cyfin/foundry-full-course-f23 solidity course.
1. Rather than based on the US Dollor per the tutorial, this stable coin is anchored (pegged) => to the Japanese Yen
   using Chainlink Price Feeds. Users exchange ETH & wBTC  => 1 yen based stablecoin. 
2. The stabiility Mechanism is algorithmic (so it is Decentralized). Users must have enough collateral to mint coins.
   The mechanism for tracking/locking collateral to stablecoin is coded.
3. Collateral Type is Exogenous (Cryptocurrency)
   a.wETH
   b.wBTC

# Getting Started
## Requirements
You will need to have git and foundry installed. You will also need to have Chainlink Brownie Contracts and Openzeppelin-Contracts installed.

### Install git and foundry
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
 - Run `git --version`. Which should result in an output like, `git version x.x.x`
- [foundry](https://getfoundry.sh/)
 - Run `forge --version` you should see an output like `forge 0.2.0 (ec3f9bd 2023-09-19T13:44:30.009787069Z)` if you've done it right.

### Install Chainlink Brownie Contracts
```
forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
```
### Install Openzeppelin-Contracts
```
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

## Quickstart
```
git clone https://github.com/chthsol/foundry-defi-stablecoin-f23
cd foundry-defi-stablecoin-f23
forge build
```

# Usage

## Start a local node
```
make anvil
```

## Deploy
```
make deploy
```
## Testing
Unit and fuzz tests are included in this repo.
They can be run all at once or individually.

Run all tests.
```
forge test
```

You can run individual tests of each function with the --match-test option.
```
forge test --match-test testFunctionName
```

To run tests in a forked environment, use the --fork-url EVM option.
You will need to have set up a .env with the appropriate rpc-url to run a fork environment.
See "Setup environment variables" in "Deploy to a testnet" below.
```
forge test --fork-url $SEPOLIA_RPC_URL
```

### Test coverage.

Check test coverage
```
forge coverage
```

# Deploy to a testnet.

1. Setup environment variables.

Create a .env file and add `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables.

- `PRIVATE_KEY` :  Private key of the account you will use to deploy. **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
- `SEPOLIA_RPC_URL`: Url of the Sepolia testnet that you will use.

2. You will need testnet ETH to deploy to testnet.

If you have an Alchemy account you can get tesnet ETH at the appropriate Alchemy ETH faucet.
[sepoliafaucet.com](https://sepoliafaucet.com/)

3. Deploy
```
make deploy ARGS="--network sepolia"
```

## Scripts
none

## Using Cast to interact with contracts.

Get wrapped ETH (WETH)
```
cast 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "deposit()" --value 0.2ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Approve WETH 
```
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "approve(address,uint256)" <dyscEngineContractAddress> 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Deposite WETH and mint DYSC
```
cast send <dyscEngineContractAddress> "depositCollateralAndMintDysc(address, uint256, uint256)" 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 1000000000000000000 10000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```