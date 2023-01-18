#!/bin/bash

contract_files=(
    "contracts/AelinFeeEscrow.sol:AelinFeeEscrow" 
    "contracts/libraries/MerkleTree.sol:MerkleTree" 
    "contracts/libraries/AelinAllowList.sol:AelinAllowList" 
    "contracts/libraries/AelinNftGating.sol:AelinNftGating" 
    "contracts/libraries/NftCheck.sol:NftCheck" 
    "contracts/AelinDeal.sol:AelinDeal"
    "contracts/AelinPool.sol:AelinPool"
)

envs_names=(
    "AelinFeeEscrow_address"
    "MerkleTree_address"
    "AelinAllowList_address"
    "AelinNftGating_address"
    "NftCheck_address"
    "AelinDeal_address"
    "AelinPool_address"
)

tresury="0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
private_key="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
addresses=()

echo "
*******  DEPLOYING ALL CONTRACTS TO PERFORM END-TO-END TESTS ********
"


# Reset foundry.toml
echo "[profile.default]
src = 'contracts'
out = 'artifacts'
libs = ['lib']
remappings = [
    '@ensdomains/=node_modules/@ensdomains/',
    '@eth-optimism/=node_modules/@eth-optimism/',
    '@openzeppelin/=node_modules/@openzeppelin/',
    'eth-gas-reporter/=node_modules/eth-gas-reporter/',
    'hardhat/=node_modules/hardhat/',
    'openzeppelin-solidity-2.3.0/=node_modules/openzeppelin-solidity-2.3.0/',
    'ds-test/=lib/forge-std/lib/ds-test/src/',
    'forge-std/=lib/forge-std/src/',
]
" > foundry.toml

# 1. Deploying contracts
for i in {1..7}
do
  contract_file=${contract_files[i]}
  env_name=${envs_names[i]}
  output=$(forge create --rpc-url http://anvil:8545 --private-key $private_key  $contract_file --config-path=./foundry.toml)
  address=$(echo $output | grep "Deployed to: " | awk '{print $3}')
  addresses+=$(echo $address)
  echo "$env_name=$address" >> .env.linuz
  echo "$env_name=$addresses[i]"
done

# 2. Updating libraries in foundry.toml
echo " 
libraries = [
    \"contracts/libraries/AelinAllowList.sol:AelinAllowList:$addresses[3]\",
    \"contracts/libraries/MerkleTree.sol:MerkleTree:$addresses[2]\",
    \"contracts/libraries/AelinNftGating.sol:AelinNftGating:$addresses[4]\"
]" >> foundry.toml

# 3. Deploying AelinUpFrontDeal
output_aelinUpFrontDeal=$(forge create --rpc-url http://anvil:8545 --private-key $private_key contracts/AelinUpFrontDeal.sol:AelinUpFrontDeal)
address_aelinUpFrontDeal=$(echo $output_aelinUpFrontDeal | grep "Deployed to: " | awk '{print $3}')
echo "AelinUpFrontDeal_address=$address_aelinUpFrontDeal" >> .env.linuz
echo "AelinUpFrontDeal_address=$address_aelinUpFrontDeal"

# 4. Deploying AelinUpFrontDealFactory
output_aelinUpFrontDealFactory=$(forge create --rpc-url http://anvil:8545 --private-key $private_key contracts/AelinUpFrontDealFactory.sol:AelinUpFrontDealFactory --constructor-args $address_aelinUpFrontDeal $addresses[1] $tresury)
address_aelinUpFrontDealFactory=$(echo $output_aelinUpFrontDealFactory | grep "Deployed to: " | awk '{print $3}')
echo "AelinUpFrontDeal_address=$address_aelinUpFrontDealFactory" >> .env.linuz
echo "AelinUpFrontDealFactory_address=$address_aelinUpFrontDealFactory"

# 5. Deploying AelinPoolFactory
output_aelinFactory=$(forge create --rpc-url http://anvil:8545 --private-key $private_key contracts/AelinPoolFactory.sol:AelinPoolFactory --constructor-args $addresses[7] $addresses[6] $tresury $addresses[1])
address_aelinFactory=$(echo $output_aelinFactory | grep "Deployed to: " | awk '{print $3}')
echo "AelinPoolFactory_address=$address_aelinFactory" >> .env.linuz
echo "AelinPoolFactory_address=$address_aelinFactory"

# 6. Deploying dummy tokens
output_uniToken=$(forge create --rpc-url http://anvil:8545 --private-key $private_key contracts/UNI.sol:UNI)
address_uniToken=$(echo $output_uniToken | grep "Deployed to: " | awk '{print $3}')
echo "UNI_address=$address_uniToken" >> .env.linuz
echo "UNI_address=$address_uniToken"
output_usdcToken=$(forge create --rpc-url http://anvil:8545 --private-key $private_key contracts/USDC.sol:USDC)
address_usdcToken=$(echo $output_usdcToken | grep "Deployed to: " | awk '{print $3}')
echo "USDC_address=$address_usdcToken" >> .env.linuz
echo "USDC_address=$address_usdcToken"

echo "

******* DONE! *******
"