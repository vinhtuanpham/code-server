FROM node:10.15.1 AS deps

# Install VS Code's deps. These are the only two it seems we need.
RUN apt-get update && apt-get install -y \
	libxkbfile-dev \
	libsecret-1-dev

# Ensure latest yarn.
RUN npm install -g yarn@1.13

WORKDIR /src
COPY . .

# In the future, we can use https://github.com/yarnpkg/rfcs/pull/53 to make yarn use the node_modules
# directly which should be fast as it is slow because it populates its own cache every time.
RUN yarn && NODE_ENV=production yarn task build:server:binary

# Docker stage we'll use later for the CLI
FROM ubuntu:18.04 AS docker

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
	apt-get update && \
	apt-get install -y docker-ce-cli

# We deploy with ubuntu so that devs have a familiar environment.
FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
	curl \
	dumb-init \
	git \
	locales \	
	openssl \
	net-tools \	
	sudo

RUN locale-gen en_US.UTF-8
# We unfortunately cannot use update-locale because docker will not use the env variables
# configured in /etc/default/locale so we need to set it manually.
ENV LC_ALL=en_US.UTF-8

RUN adduser --gecos '' --disabled-password coder && \
	echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

USER coder
# We create first instead of just using WORKDIR as when WORKDIR creates, the user is root.
RUN mkdir -p /home/coder/project
WORKDIR /home/coder/project

EXPOSE 8443
ENTRYPOINT ["dumb-init", "code-server"]

COPY --from=docker /usr/bin/docker /usr/local/bin/docker
COPY --from=deps /src/packages/server/cli-linux-x64 /usr/local/bin/code-server
