# Variables
DOCKER_IMAGE_NAME = bart0llo
DOCKER_PREFIX = ghcr.io/bart0llo
VERSION := $(shell jq -r .version ./package.json)

# Targets
.PHONY: help build push remove create-env update-env list-env

# Default target
help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  help              - Show this help message"
	@echo "  build             - Build Docker image"
	@echo "  push              - Push Docker image to registry"
	@echo "  remove            - Remove Docker images for this build only"

# Build Docker image
build:
	sudo docker build -t $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME):v$(VERSION) . && \
	sudo docker tag $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME):v$(VERSION) $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME):latest

# Push Docker image to the registry
push:
	sudo docker push $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME):v$(VERSION) && \
	sudo docker push $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME):latest

# Remove Docker images for this build only
remove:
	@echo "Removing Docker images for $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME)..."
	@images=$$(sudo docker images -q $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME)); \
	if [ -n "$$images" ]; then \
		sudo docker rmi -f $$images; \
		echo "Removed Docker images for $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME)."; \
	else \
		echo "No Docker images found for $(DOCKER_PREFIX)/$(DOCKER_IMAGE_NAME)."; \
	fi