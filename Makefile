.PHONY: build test push clean help shell inspect

IMAGE_NAME ?= ghcr.io/donaldgifford/github-runner-base
IMAGE_TAG ?= latest

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the Docker image locally
	docker buildx bake local

test: build ## Build and test the image
	@echo "Testing installed tools..."
	docker run --rm $(IMAGE_NAME):local bash -c " \
		curl --version && \
		wget --version && \
		tar --version && \
		git --version && \
		jq --version && \
		unzip -v && \
		python3 --version && \
		gcc --version \
	"
	@echo "All tests passed!"

shell: build ## Run an interactive shell in the container
	docker run --rm -it $(IMAGE_NAME):local /bin/bash

push: ## Push the image to registry
	docker buildx bake ci-push --set ci-push.tags=$(IMAGE_NAME):$(IMAGE_TAG)

clean: ## Remove built images
	docker rmi $(IMAGE_NAME):local 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true

inspect: build ## Show image details
	@echo "Image size:"
	@docker images $(IMAGE_NAME):local --format "{{.Size}}"
	@echo "\nImage layers:"
	@docker history $(IMAGE_NAME):local
