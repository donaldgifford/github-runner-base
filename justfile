# github-runner-base — task runner
#
# Project automation via just. This repo builds exactly one artifact: a
# container image. Every build path goes through `docker buildx bake` so
# local runs and CI share the target definitions in docker-bake.hcl.
#
# Tooling comes from mise (`mise install`); CI installs the same versions
# via jdx/mise-action, so `just lint` means the same thing in both places.

set shell := ["bash", "-euo", "pipefail", "-c"]

registry   := "ghcr.io"
image_name := "donaldgifford/github-runner-base"
image      := registry / image_name

# Default: list recipes
_default:
    @just --list --unsorted

# ─── Build ──────────────────────────────────────────────────────────

# Build the image for the host platform and load it into Docker
[group('build')]
build:
    @docker buildx bake dev

# Build the linux/amd64 PR-validation image and load it into Docker
[group('build')]
build-ci:
    @docker buildx bake ci

# Build and push the multi-arch release image (CI does this; needs registry auth)
[group('build')]
push:
    @docker buildx bake release

# Remove the locally built images
[group('build')]
clean:
    -@docker rmi {{ image }}:dev {{ image }}:ci 2>/dev/null
    @echo "✓ Cleaned local images"

# Build the image only if that tag is not already in the local daemon. The
# bake target names match the tags they produce, so the tag doubles as the
# target to build.
_ensure tag:
    @docker image inspect {{ image }}:{{ tag }} >/dev/null 2>&1 \
        || docker buildx bake {{ tag }}

# ─── Test & inspect ─────────────────────────────────────────────────

# Verify every tool the setup-* actions depend on is present in the image
[group('test')]
test tag="dev": (_ensure tag)
    @docker run --rm {{ image }}:{{ tag }} bash -c '\
        set -e; \
        curl --version; \
        wget --version; \
        tar --version; \
        gzip --version; \
        unzip -v; \
        git --version; \
        jq --version; \
        python3 --version; \
        gcc --version; \
    ' > /dev/null
    @echo "✓ All expected tools present in {{ image }}:{{ tag }}"

# Interactive shell in the image
[group('test')]
shell tag="dev": (_ensure tag)
    @docker run --rm -it {{ image }}:{{ tag }} /bin/bash

# Show image size and layer history
[group('test')]
inspect tag="dev": (_ensure tag)
    @docker images {{ image }}:{{ tag }}
    @echo ""
    @docker history {{ image }}:{{ tag }}

# ─── Security ───────────────────────────────────────────────────────

# Write an SPDX SBOM for the local image to sbom.spdx.json
[group('security')]
sbom tag="dev": (_ensure tag)
    @syft scan docker:{{ image }}:{{ tag }} -o spdx-json=sbom.spdx.json
    @echo "✓ SBOM written to sbom.spdx.json"

# Scan the local image — the same gate CI applies to PRs
[group('security')]
scan tag="dev": (_ensure tag)
    @trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 \
        --ignorefile .trivyignore.yaml {{ image }}:{{ tag }}
    @echo "✓ No fixable CRITICAL vulnerabilities in {{ image }}:{{ tag }}"

# Full severity report for the local image — informational, never fails
[group('security')]
scan-report tag="dev": (_ensure tag)
    @trivy image --severity CRITICAL,HIGH,MEDIUM {{ image }}:{{ tag }}

# Verify the signature, attestations, and SBOM on a published tag
[group('security')]
verify tag="latest":
    @echo "→ cosign signature"
    @cosign verify {{ image }}:{{ tag }} \
        --certificate-identity-regexp '^https://github\.com/{{ image_name }}/' \
        --certificate-oidc-issuer https://token.actions.githubusercontent.com \
        -o text
    @echo "→ SLSA provenance attestation"
    @gh attestation verify "oci://{{ image }}:{{ tag }}" --repo {{ image_name }}
    @echo "→ in-registry attestation manifests (SBOM + provenance)"
    @docker buildx imagetools inspect {{ image }}:{{ tag }} --raw \
        | jq -r '.manifests[] | select(.annotations["vnd.docker.reference.type"] == "attestation-manifest") | "  attests " + .annotations["vnd.docker.reference.digest"]'

# ─── Lint & format ──────────────────────────────────────────────────

# Run every linter — this is exactly what CI runs
[group('lint')]
lint: lint-dockerfile lint-actions lint-yaml lint-markdown lint-format
    @echo "✓ All linters passed"

# Lint the Dockerfile with hadolint
[group('lint')]
lint-dockerfile:
    @hadolint Dockerfile

# Lint GitHub Actions workflows
[group('lint')]
lint-actions:
    @actionlint

# Lint YAML
[group('lint')]
lint-yaml:
    @yamllint .

# Lint Markdown
[group('lint')]
lint-markdown:
    @markdownlint-cli2 "**/*.md"

# Check formatting without writing changes
[group('lint')]
lint-format:
    @prettier --check .

# Format YAML, Markdown, and JSON in place
[group('lint')]
fmt:
    @yamlfmt
    @prettier --write .
    @markdownlint-cli2 --fix "**/*.md"
    @echo "✓ Formatted"

# ─── Changelog ──────────────────────────────────────────────────────
# No manual tag recipe on purpose: the release workflow cuts tags from the
# merged PR's semver label. Merge with major/minor/patch to release,
# dont-release to skip.

# Regenerate CHANGELOG.md from conventional commits
[group('changelog')]
changelog:
    @git-cliff -o CHANGELOG.md
    @echo "✓ CHANGELOG.md regenerated"

# Preview the changelog entries for unreleased commits
[group('changelog')]
changelog-preview:
    @git-cliff --unreleased

# ─── Composite gates ────────────────────────────────────────────────

# Pre-commit gate: lint only, no image build
[group('gate')]
check: lint

# Local equivalent of PR CI: lint, build, verify tools, scan
[group('gate')]
ci: lint build-ci (test "ci") (scan "ci")
    @echo "✓ CI pipeline complete"
