# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Custom GitHub Actions runner Docker image extending `ghcr.io/actions/actions-runner:latest` with additional utilities (curl, wget, tar, build-essential, jq, python3, etc.) for compatibility with common setup actions (setup-go, setup-node, setup-python). Designed for use with GitHub's Actions Runner Controller (ARC) on Kubernetes.

## Build and Test Commands

```bash
make build          # Build the Docker image locally (uses bake "local" target)
make test           # Build and verify all tools are installed
make shell          # Interactive shell in the container
make inspect        # Show image size and layers
make clean          # Remove built images
make push           # Push to GHCR (uses bake "ci-push" target)
```

Image name/tag can be overridden: `make build IMAGE_NAME=ghcr.io/foo/bar IMAGE_TAG=v1.0.0`

## Docker Bake

Builds are managed via `docker-bake.hcl`. All Makefile and CI targets use `docker buildx bake`.

| Target | Platform | Output | Purpose |
|--------|----------|--------|---------|
| `local` | native | docker | Local dev builds |
| `test` | native | docker | Local test builds |
| `ci-local` | linux/amd64 | docker | PR CI builds (loaded for testing) |
| `ci-push` | linux/amd64, linux/arm64 | registry | Push builds on main/tags |

CI overrides tags/labels via `--set` from `docker/metadata-action` output.

## CI/CD

GitHub Actions workflow (`.github/workflows/build-and-push.yml`):
- PRs: builds via `ci-local` bake target, runs tool verification tests
- Push to main / tags (`v*`): builds via `ci-push` bake target, pushes to `ghcr.io/donaldgifford/github-runner-base`
- Uses GitHub Actions cache (GHA) for Docker layer caching

Renovate is configured (`renovate.json5`) using shared presets from `donaldgifford/renovate-config` for automated dependency updates (Docker base images, CI actions, mise tools).

## Key Architecture Decisions

- Dockerfile switches to `USER root` for package installation, then back to `USER runner` for ARC compatibility
- Single `RUN` layer for all apt packages to minimize image size
- Uses `--no-install-recommends` to keep image lean — maintain this when adding packages
- Examples in `examples/` show ARC integration (RunnerDeployment and Helm values)
