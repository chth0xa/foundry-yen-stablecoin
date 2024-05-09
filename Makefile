-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean:; forge clean

# Remove modules
remove:; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update dependencies
update:; forge update

build:; forge build

test:; forge test

snapshot:; forge snapshot

format:; forge fmt

anvil:
	anvil; anvil --mt 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Deploy to appropriate network
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy-sepolia:
    @forge script script/DeployDecentralizedYenStableCoin.s.sol:DeployDecentralizedYenStableCoin $(NETWORK_ARGS)

#DepositCollateral:
#    @forge script/Interactions.s.sol:<ContractName> $(NETWORK_ARGS)

#RedeemCollateral:
#    @forge script/Interactions.s.sol:<ContractName> $(NETWORK_ARGS)

#MintDysc:
#    @forge script/Interactions.s.sol:<ContractName> $(NETWORK_ARGS)

#DepositCollateralAndMintDysc:
#    @forge script/Interactions.s.sol:<ContractName> $(NETWORK_ARGS)

#BurnDysc:
#    @forge script/Interactions.s.sol:<ContractName> $(NETWORK_ARGS)

#Liquidate:
#    @forge script/Interactions.s.sol:<ContractName> $(NETWORK_ARGS)




