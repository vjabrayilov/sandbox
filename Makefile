BASE_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
BUILDER_BASE_IMG := debian:bullseye-slim
DOCKER_NAMESPACE := vjabrayilov

DPDK_IMG := dpdk
DPDK_DEVBIND_IMG := dpdk-devbind
DPDK_MOD_IMG := dpdk-mod
DPDK_MOD_KERNEL := $(shell uname -r)
DPDK_TARGET := /usr/local/src/dpdk-$(DPDK_VERSION)
DPDK_VERSION :=  19.11.14

RR_VERSION := 5.8.0
RUST_VERSION := 1.75
RUST_BASE_IMG := rust:$(RUST_VERSION)-slim-bullseye

SANDBOX_IMG := sandbox
SANDBOX := $(DOCKER_NAMESPACE)/$(SANDBOX_IMG):$(DPDK_VERSION)-$(RUST_VERSION)
SANDBOX_LATEST := $(DOCKER_NAMESPACE)/$(SANDBOX_IMG):latest

.PHONY: build-all pull-all push-all \
        build-dpdk build-devbind build-mod build-sandbox \
        pull-dpdk pull-devbind pull-mod pull-sandbox \
        push-dpdk push-dpdk-latest push-devbind push-debind-latest push-mod \
        push-sandbox push-sandbox-latest \
        connect-sandbox run-sandbox test-sandbox

build-dpdk: ## Build the DPDK Docker image
	@docker build --target $(DPDK_IMG) \
		--build-arg BUILDER_BASE_IMG=$(BUILDER_BASE_IMG) \
		--build-arg DPDK_VERSION=$(DPDK_VERSION) \
		-t $(DOCKER_NAMESPACE)/$(DPDK_IMG):$(DPDK_VERSION) $(BASE_DIR)

build-devbind: ## Build the DPDK devbind Docker image
	@docker build --target $(DPDK_DEVBIND_IMG) \
		--build-arg BUILDER_BASE_IMG=$(BUILDER_BASE_IMG) \
		--build-arg DPDK_VERSION=$(DPDK_VERSION) \
		-t $(DOCKER_NAMESPACE)/$(DPDK_DEVBIND_IMG):$(DPDK_VERSION) $(BASE_DIR)

build-mod: ## Build the DPDK mod Docker image
	@docker build --target $(DPDK_MOD_IMG) \
		--build-arg BUILDER_BASE_IMG=$(BUILDER_BASE_IMG) \
		--build-arg DPDK_VERSION=$(DPDK_VERSION) \
		-t $(DOCKER_NAMESPACE)/$(DPDK_MOD_IMG):$(DPDK_VERSION)-$(DPDK_MOD_KERNEL) $(BASE_DIR)

build-sandbox: ## Build the sandbox Docker image
	@docker build --target $(SANDBOX_IMG) \
		--build-arg BUILDER_BASE_IMG=$(BUILDER_BASE_IMG) \
		--build-arg DEBUG=true \
		--build-arg DPDK_VERSION=$(DPDK_VERSION) \
		--build-arg RR_VERSION=$(RR_VERSION) \
		--build-arg RUST_BASE_IMG=$(RUST_BASE_IMG) \
		-t $(SANDBOX) $(BASE_DIR)

build-all: build-dpdk build-devbind build-mod build-sandbox ## Build all Docker images (dpdk, devbind, mod, sandbox)

connect-sandbox: ## Connect to the sandbox container
	@docker exec -it $(SANDBOX_IMG) /bin/bash

pull-all: pull-dpdk pull-devbind pull-mod pull-sandbox ## Pull all Docker images

pull-dpdk: ## Pull the DPDK Docker image
	@docker pull $(DOCKER_NAMESPACE)/$(DPDK_IMG):$(DPDK_VERSION)

pull-devbind: ## Pull the DPDK devbind Docker image
	@docker pull $(DOCKER_NAMESPACE)/$(DPDK_DEVBIND_IMG):$(DPDK_VERSION)

pull-mod: ## Pull the DPDK mod image
	@docker pull $(DOCKER_NAMESPACE)/$(DPDK_MOD_IMG):$(DPDK_VERSION)-$(DPDK_MOD_KERNEL)

pull-sandbox: ## Pull the sandbox Docker image
	@docker pull $(SANDBOX)

push-all: push-dpdk push-dpdk-latest push-devbind push-devbind-latest push-mod \
          push-sandbox push-sandbox-latest ## Push all Docker images

push-dpdk: ## Push the DPDK Docker image
	@docker push $(DOCKER_NAMESPACE)/$(DPDK_IMG):$(DPDK_VERSION)

push-dpdk-latest: ## Tag and push the DPDK Docker image as the latest
	@docker tag $(DOCKER_NAMESPACE)/$(DPDK_IMG):$(DPDK_VERSION) $(DOCKER_NAMESPACE)/$(DPDK_IMG):latest
	@docker push $(DOCKER_NAMESPACE)/$(DPDK_IMG):latest

push-devbind: ## Push the DPDK devbind image
	@docker push $(DOCKER_NAMESPACE)/$(DPDK_DEVBIND_IMG):$(DPDK_VERSION)

push-devbind-latest: ## Tag and push the DPDK devbind Docker image as the latest
	@docker tag $(DOCKER_NAMESPACE)/$(DPDK_DEVBIND_IMG):$(DPDK_VERSION) $(DOCKER_NAMESPACE)/$(DPDK_DEVBIND_IMG):latest
	@docker push $(DOCKER_NAMESPACE)/$(DPDK_DEVBIND_IMG):latest

push-mod: ## Push the DPDK mod Docker image
	@docker push $(DOCKER_NAMESPACE)/$(DPDK_MOD_IMG):$(DPDK_VERSION)-$(DPDK_MOD_KERNEL)

push-sandbox: ## Push the sandbox Docker image
	@docker push $(SANDBOX)

push-sandbox-latest: ## Tag and push the sandbox Docker image as the latext version
	@docker tag $(SANDBOX) $(SANDBOX_LATEST)
	@docker push $(SANDBOX_LATEST)

run-sandbox: ## Run the sandbox
	@if [ "$$(docker images -q $(SANDBOX))" = "" ]; then \
	docker pull $(SANDBOX); \
	fi
	@docker run -it --rm --privileged --network=host --name $(SANDBOX_IMG) \
	--cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
	-w /home/capsule \
	-v /lib/modules:/lib/modules \
	-v /dev/hugepages:/dev/hugepages \
	-v $(BASE_DIR)/capsule:/home/capsule \
	-v $(BASE_DIR)/ffp:/home/ffp \
	$(SANDBOX) /bin/bash

test-sandbox: ## Run the tests in the sandbox Docker container
	@if [ "$$(docker images -q $(SANDBOX))" = "" ]; then \
	docker pull $(SANDBOX); \
	fi
	@docker run --rm --privileged --network=host --name $(SANDBOX_IMG) \
	-w /home/capsule \
	-v /lib/modules:/lib/modules \
	-v /dev/hugepages:/dev/hugepages \
	-v $(BASE_DIR)/capsule:/home/capsule \
	$(SANDBOX) make test

help: ## Print this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
