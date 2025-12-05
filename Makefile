-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops && forge install smartcontractkit/chainlink-evm

anvil :; anvil --state state.json
