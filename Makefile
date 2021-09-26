NODE_VER=16-alpine
EXPLORER_VER=3.2.0 

login:
	docker login

list-builders:
	docker buildx ls

initialise-builder:
	docker buildx create --name builder
	docker buildx use builder
	docker buildx inspect builder --bootstrap

build:
	docker buildx build \
		--platform linux/amd64,linux/arm64,linux/arm/v7 \
		-t barneybuffet/btc-rpc-explorer:$(EXPLORER_VER) \
		-t barneybuffet/btc-rpc-explorer:latest \
		--build-arg NODE_VER=$(NODE_VER) \
		--build-arg EXPLORER_VER=$(EXPLORER_VER) \
		--push \
		. \

build-docs:
	mkdocs build

CONTAINER_NAME:=multi-arch-test
run:
	docker run -i -d --rm \
		-p 9050:9050 \
		--name $(CONTAINER_NAME) \
		barneybuffet/bitcoin-core

ARM_SHA?=660432aec93b84c61d24541e5cf135491829df01ac900a20de325f8726f6118c
run-arm:
	docker run -i -d --rm \
		-p 9050:9050 \
		--name $(CONTAINER_NAME) \
		barneybuffet/bitcoin-core@sha256:$(ARM_SHA)

stop:
	docker stop $(CONTAINER_NAME)

inspect:
	docker buildx imagetools inspect barneybuffet/bitcoin-core:latest

test-install-linux:
	curl -LO https://storage.googleapis.com/container-structure-test/latest/container-structure-test-linux-amd64 && chmod +x container-structure-test-linux-amd64 && mkdir -p $HOME/bin && export PATH=$PATH:$HOME/bin && mv container-structure-test-linux-amd64 $HOME/bin/container-structure-test

test-install-osx:
	curl -LO https://storage.googleapis.com/container-structure-test/latest/container-structure-test-darwin-amd64 && chmod +x container-structure-test-darwin-amd64 && sudo mv container-structure-test-darwin-amd64 /usr/local/bin/container-structure-test

test:
	container-structure-test test \
		--image bitcoin-core:0.4.6.6 \
		--config unit-tests.yml
