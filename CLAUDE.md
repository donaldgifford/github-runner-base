# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

Custom GitHub Actions runner Docker image extending
`ghcr.io/actions/actions-runner` with additional utilities (curl, wget, tar,
build-essential, jq, python3, etc.) for compatibility with common setup actions
(setup-go, setup-node, setup-python). Designed for use with GitHub's Actions
Runner Controller (ARC) on Kubernetes.

The repo produces exactly one artifact: a container image. There is no
application code.

## Build and Test Commands

`just` is the task runner — there is no Makefile. Tooling is pinned in
`mise.toml`; run `mise install` once.

```bash
just               # list all recipes
just build         # build for the host platform, load into Docker
just build-ci      # linux/amd64 PR-validation build, loaded into Docker
just test          # verify expected tools are present in the image
just shell         # interactive shell in the container
just inspect       # image size and layers
just clean         # remove built images
just push          # multi-arch build + push (CI does this; needs registry auth)

just lint          # hadolint + actionlint + yamllint + markdownlint + prettier
just fmt           # format YAML/Markdown/JSON in place
just scan          # Trivy scan — the same gate CI applies to PRs
just sbom          # write an SPDX SBOM to sbom.spdx.json
just verify        # cosign signature + attestations on a published tag
just ci            # full local equivalent of PR CI
```

Most recipes take an optional tag argument (`just test ci`, `just scan ci`) and
build the image first if it isn't already in the local daemon.

## Docker Bake

Builds are managed via `docker-bake.hcl`. Every path — `just`, CI, and release —
goes through `docker buildx bake`.

| Target    | Platform           | Output          | Purpose                              |
| --------- | ------------------ | --------------- | ------------------------------------ |
| `dev`     | native             | docker (loaded) | Local dev builds                     |
| `ci`      | linux/amd64        | docker (loaded) | PR builds — loaded so Trivy can scan |
| `release` | linux/amd64, arm64 | registry        | Push on main, with SBOM + provenance |

Cache backends are deliberately **not** declared in the HCL: `type=gha` only
works inside GitHub Actions, so baking it in would break every local build. CI
layers it on via `--set *.cache-from=...`.

The `release` target inherits from a `docker-metadata-action` stub that declares
default tags. CI overrides that target wholesale with `docker/metadata-action`'s
bake-file output. `release` declares no tags of its own — with HCL inheritance a
child's tags list _replaces_ the parent's, so the stub is what makes the
override take effect.

## CI/CD

| Workflow              | Trigger                | Does                                                           |
| --------------------- | ---------------------- | -------------------------------------------------------------- |
| `ci.yml`              | PR, push to main       | Lint, build `ci` target, verify tools, SBOM, Trivy scan + gate |
| `release.yml`         | push to main, dispatch | Tag from PR label, multi-arch push, cosign sign, attest        |
| `codeql.yml`          | PR, push, weekly       | CodeQL `actions` analysis of the workflows themselves          |
| `image-scan.yml`      | weekly, dispatch       | Rescan the _published_ image so post-release CVEs surface      |
| `trufflehog.yml`      | PR, push to main       | Secret scanning                                                |
| `pr-labels.yml`       | PR                     | Require exactly one semver label                               |
| `changelog-regen.yml` | push to main           | Regenerate `CHANGELOG.md` with git-cliff and auto-commit       |

### Supply chain

Published images carry a cosign signature, a Sigstore-signed SLSA provenance
attestation, a Sigstore-signed SPDX SBOM attestation, and BuildKit's own
in-registry SBOM + provenance manifests. `just verify` checks all of it. Do not
remove any of these without saying so explicitly — they are the point of the
release pipeline.

### Vulnerability scanning

Two Trivy passes on purpose, in both `ci.yml` and `image-scan.yml`:

1. **Report** — `CRITICAL,HIGH`, including unfixed, uploaded as SARIF to code
   scanning. Never fails.
2. **Gate** — `CRITICAL` only, `--ignore-unfixed`, `exit-code: 1`. This is what
   blocks the PR.

The gate skips unfixable findings deliberately: a CVE with no available fix in
the upstream runner base image is not something a PR here can act on, and
blocking on it only teaches people to ignore red. The usual fix for a real
finding is bumping the pinned base image digest. Genuine exceptions go in
`.trivyignore.yaml` with a comment.

Making code scanning results _block_ merges also requires branch protection
("Require code scanning results") in repo settings — that is a GitHub setting,
not something this repo can configure.

## Key Architecture Decisions

- The base image in the `Dockerfile` is pinned to an immutable digest, never
  `:latest`. Renovate's dockerfile manager (`pinDigests: true`, from the shared
  `:docker` preset) bumps the tag and digest together — never hand-edit one
  without the other. The `# syntax=` directive is pinned the same way.
- Dockerfile switches to `USER root` for package installation, then back to
  `USER runner` for ARC compatibility
- Single `RUN` layer for all apt packages to minimize image size
- Uses `--no-install-recommends` to keep image lean — maintain this when adding
  packages
- apt package versions are intentionally unpinned (hadolint DL3008 is suppressed
  in `.hadolint.yaml` with the reasoning); reproducibility comes from the base
  image digest, and Trivy is what catches a vulnerable package
- Examples in `examples/` show ARC integration (RunnerDeployment and Helm
  values)

## Conventions

- Renovate (`renovate.json5`) extends shared presets from
  `donaldgifford/renovate-config`. The `:ci` preset sets `pinDigests: true` for
  GitHub Actions, so writing `@v7` in a workflow is fine — Renovate pins it to a
  SHA on its next run.
- `scripts/labels.sh` creates every label referenced by `.github/labeler.yml`
  and `pr-labels.yml`. Add a label to one of those files, then run the script.
- `CHANGELOG.md` is generated by git-cliff. Do not hand-edit it; it is excluded
  from prettier and markdownlint for that reason.
