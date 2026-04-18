# ——————————————— INSTALL ———————————————
install:
	forge install OpenZeppelin/openzeppelin-contracts@master
	forge install smartcontractkit/chainlink-brownie-contracts

# ——————————————— BUILD ———————————————
build:
	forge build

clean:
	forge clean

# ——————————————— TEST ———————————————
test:
	forge test

test-v:
	forge test -vvvv

test-gas:
	forge test --gas-report

snapshot:
	forge snapshot

# ——————————————— FORMAT ———————————————
fmt:
	forge fmt

fmt-check:
	forge fmt --check

# ——————————————— STATIC ANALYSIS ———————————————
slither:
	slither .

aderyn:
	aderyn .

# ——————————————— FUZZ ———————————————
echidna:
	echidna . --contract $(contract)

# ——————————————— FORMAL VERIFICATION ———————————————
halmos:
	halmos

certora:
	certoraRun $(conf)

# ——————————————— DEPLOY ———————————————
deploy-anvil:
	forge script script/$(script) --rpc-url http://localhost:8545/ --broadcast

deploy:
	forge script script/$(script) --rpc-url $(rpc) --broadcast --verify

# ——————————————— INTERACT ———————————————
interact:
	forge script script/$(script) --rpc-url $(rpc) --broadcast
