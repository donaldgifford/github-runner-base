# GitHub Actions Runner with Extended Tooling
# This image extends the official GitHub Actions runner with additional utilities
# required for common setup actions (setup-go, setup-node, setup-python, etc.)

FROM ghcr.io/actions/actions-runner:latest

# Switch to root to install packages
USER root

# Update and install essential tools needed by GitHub Actions setup-* actions
RUN apt-get update && apt-get install -y \
    # Core utilities for downloading and extracting
    curl \
    wget \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    unzip \
    zip \
    # Version control (git should already be present but ensuring it's there)
    git \
    # SSL/TLS certificates for HTTPS
    ca-certificates \
    # Build essentials for actions that compile code
    build-essential \
    # Additional tools commonly needed
    jq \
    gnupg \
    lsb-release \
    software-properties-common \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch back to the runner user (important for ARC compatibility)
USER runner

# Metadata
LABEL org.opencontainers.image.source="https://github.com/donaldgifford/github-runner-base"
LABEL org.opencontainers.image.description="GitHub Actions Runner with extended tooling for setup actions"
LABEL org.opencontainers.image.licenses="MIT"
