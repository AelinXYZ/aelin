FROM node:14-alpine as step1

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Clone the repository
RUN apk update && apk add git
RUN git clone https://github.com/AelinXYZ/aelin.git .
RUN git checkout e2e-devops

RUN npm i

FROM linuzeth/aelin-anvil as step2

RUN apk update && apk add bash

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY --from=step1 /usr/src/app ./

RUN forge build

ENTRYPOINT ["/bin/bash", "-c"]