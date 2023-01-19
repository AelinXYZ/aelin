FROM node:14-alpine as installer

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Clone the repository
RUN apk update && apk add git
RUN git clone https://github.com/AelinXYZ/aelin.git .
RUN git checkout e2e-devops

RUN npm i

#only keep repmappings
RUN mkdir -p ./remappings
RUN mv ./node_modules/@ensdomains ./remappings/@ensdomains
RUN mv ./node_modules/@eth-optimism ./remappings/@eth-optimism
RUN mv ./node_modules/@openzeppelin ./remappings/@openzeppelin
RUN mv ./node_modules/eth-gas-reporter ./remappings/eth-gas-reporter
RUN mv ./node_modules/hardhat ./remappings/hardhat
RUN mv ./node_modules/openzeppelin-solidity-2.3.0 ./remappings/openzeppelin-solidity-2.3.0/

# no need to keep this
RUN rm -rf ./node_modules

FROM linuzeth/aelin-anvil as builder

RUN apk update && apk add bash

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY --from=installer /usr/src/app/ ./

# Create custom config file with remappings path
RUN printf "\
    [profile.default]\n\
    src = 'contracts'\n\
    out = 'artifacts'\n\
    libs = ['lib']\n\
    remappings = [\n\
    '@ensdomains/=remappings/@ensdomains/',\n\
    '@eth-optimism/=remappings/@eth-optimism/',\n\
    '@openzeppelin/=remappings/@openzeppelin/',\n\
    'eth-gas-reporter/=remappings/eth-gas-reporter/',\n\
    'hardhat/=remappings/hardhat/',\n\
    'openzeppelin-solidity-2.3.0/=remappings/openzeppelin-solidity-2.3.0/',\n\
    'ds-test/=lib/forge-std/lib/ds-test/src/',\n\
    'forge-std/=lib/forge-std/src/',\n\
    ]" > foundry.toml

RUN forge build

ENTRYPOINT ["/bin/bash", "-c"]