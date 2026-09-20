# syntax=docker/dockerfile:1.27.0@sha256:bde3983e9c939224420ddaf6b784cc30e09b035a4dea01f581230c50809f372e
# GitHub Actions Runner with Extended Tooling
# This image extends the official GitHub Actions runner with additional utilities
# required for common setup actions (setup-go, setup-node, setup-python, etc.)

# Pinned to an immutable digest rather than :latest so every build is
# reproducible and a base-image bump arrives as a reviewable PR. Renovate's
# dockerfile manager (pinDigests: true, via the shared :docker preset) bumps
# the tag and the digest together — do not hand-edit one without the other.
FROM ghcr.io/actions/actions-runner:2.337.0@sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4

# Switch to root to install packages
USER root

# Update and install essential tools needed by GitHub Actions setup-* actions
RUN apt-get update && apt-get install -y --no-install-recommends \
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
  libsqlite3-dev \
  python3 \
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
