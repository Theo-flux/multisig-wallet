-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops && forge install smartcontractkit/chainlink-evm

deploy-anvil :
	@forge script script/DeployMultiSigWallet.s.sol:DeployMultiSigWallet --rpc-url $(ANVIL_LOCAL_RPC_URL)	

deploy-sepolia :
	@forge script script/DeployMultiSigWallet.s.sol:DeployMultiSigWallet --rpc-url $(ALCHEMY_SEPOLIA_RPC_URL) --account eth_account_one --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
