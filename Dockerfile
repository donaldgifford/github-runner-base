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

# Update and install essential tools needed by GitHub Actions setup-* actions.
#
# The package set is chosen against the GitHub-hosted runner manifest
# (actions/runner-images images/ubuntu/Ubuntu2604-Readme.md) so workflows
# written for `ubuntu-latest` mostly work here unchanged. It is deliberately
# NOT the whole manifest — matching hosted wholesale pushes an image past
# 18GB, and anything version-sensitive (kubectl, helm, yq, kustomize) belongs
# in a repo's own mise.toml rather than frozen into this base.
RUN apt-get update && apt-get install -y --no-install-recommends \
  # Core utilities for downloading, transferring, and extracting
  curl \
  wget \
  rsync \
  tar \
  gzip \
  bzip2 \
  xz-utils \
  unzip \
  zip \
  # Compression formats the cache and artifact actions reach for
  zstd \
  lz4 \
  pigz \
  # Version control (git should already be present but ensuring it's there)
  git \
  # SSL/TLS certificates for HTTPS
  ca-certificates \
  # Build essentials for actions that compile code, plus the autotools chain
  # and the headers native gem/wheel builds expect. build-essential alone is
  # not enough once anything runs ./configure.
  build-essential \
  autoconf \
  automake \
  libtool \
  m4 \
  pkg-config \
  libsqlite3-dev \
  libssl-dev \
  libyaml-dev \
  # Python. python-is-python3 so a bare `python` resolves — a lot of
  # third-party scripts assume it does.
  python3 \
  python-is-python3 \
  # Additional tools commonly needed
  file \
  jq \
  locales \
  lsb-release \
  gnupg \
  software-properties-common \
  sqlite3 \
  # envsubst, for templating manifests and config from the job environment.
  # Must be explicit: nothing else here pulls gettext-base in, verified by
  # dry-running the entire hosted apt manifest both with and without
  # recommends. It is not present on hosted runners either.
  gettext-base \
  # Network inspection, for debugging connectivity from inside a runner pod
  iproute2 \
  iputils-ping \
  # Cleanup
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# uv manages Python on the runner: interpreters (`uv python install`) and
# Python CLI tools. mise's pypi/pipx backend switches to `uvx` when uv is on
# PATH, so `pipx:` tools in a repo's mise.toml install without pipx. uv's
# default python-preference (`managed`) still uses the system python3 when it
# satisfies a request, so a job downloads an interpreter only when it pins a
# different version. Copied from Astral's image (their documented install
# path) and pinned by digest; Renovate bumps tag and digest together.
COPY --from=ghcr.io/astral-sh/uv:0.12.19@sha256:04d046b13e60d6bcec73cbc5e1cad25d680dea90c8573340950a0ac2d1aef424 /uv /uvx /usr/local/bin/

# Switch back to the runner user (important for ARC compatibility)
USER runner
