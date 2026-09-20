# GitHub Runner Base Image

A custom GitHub Actions runner image that extends the official
`ghcr.io/actions/actions-runner` with additional utilities required for common
setup actions.

The base image is pinned to an immutable digest rather than `:latest`, so builds
are reproducible and base-image bumps arrive as reviewable Renovate PRs.

## Why This Image?

The official GitHub Actions runner image is minimal and lacks some tools
required by popular setup actions like:

- `actions/setup-go`
- `actions/setup-node`
- `actions/setup-python`
- And many others

This image adds those dependencies while maintaining full compatibility with
GitHub's Actions Runner Controller (ARC) for Kubernetes.

## What's Included

This image adds the following tools on top of the official runner:

- **Download utilities**: `curl`, `wget`
- **Archive tools**: `tar`, `gzip`, `bzip2`, `xz-utils`, `unzip`, `zip`
- **Build tools**: `build-essential` (gcc, g++, make)
- **Utilities**: `jq`, `git`, `ca-certificates`, `gnupg`

## Building the Image

Install the toolchain with [mise](https://mise.jdx.dev) (`mise install`), then
use [just](https://just.systems). Every build path goes through
`docker buildx bake`, so local builds and CI share the target definitions in
`docker-bake.hcl`.

```bash
just               # list every recipe
just build         # build for the host platform, load into Docker
just test          # verify all expected tools are present in the image
just shell         # interactive shell in the image
just scan          # vulnerability scan (the same gate CI applies to PRs)
just sbom          # write an SPDX SBOM to sbom.spdx.json
just lint          # everything CI lints: Dockerfile, workflows, YAML, Markdown
just ci            # full local equivalent of PR CI
```

Releases are cut by CI, not by hand — see [Releasing](#releasing).

## Supply Chain

Every published image carries, and is verifiable against:

| Artifact         | Produced by                          | Verify with                                 |
| ---------------- | ------------------------------------ | ------------------------------------------- |
| Signature        | `cosign sign` (keyless, GitHub OIDC) | `cosign verify`                             |
| SLSA provenance  | `actions/attest-build-provenance`    | `gh attestation verify`                     |
| SBOM (SPDX)      | `actions/attest-sbom`                | `gh attestation verify`                     |
| In-registry SBOM | BuildKit `attest type=sbom`          | `docker buildx imagetools inspect --format` |
| In-registry SLSA | BuildKit `attest type=provenance`    | `docker buildx imagetools inspect --format` |

All of it at once:

```bash
just verify              # defaults to :latest
just verify v1.2.3
```

Or by hand:

```bash
cosign verify ghcr.io/donaldgifford/github-runner-base:latest \
  --certificate-identity-regexp '^https://github\.com/donaldgifford/github-runner-base/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/donaldgifford/github-runner-base:latest \
  --repo donaldgifford/github-runner-base
```

The image is scanned with Trivy on every pull request and weekly against the
published tag. Results land in the repository's **Security → Code scanning**
tab; a fixable `CRITICAL` finding fails the PR.

## Releasing

Merging to `main` cuts a release. The version comes from the merged PR's label:

| Label          | Effect                    |
| -------------- | ------------------------- |
| `major`        | `1.x.x` → `2.0.0`         |
| `minor`        | `1.2.x` → `1.3.0`         |
| `patch`        | `1.2.3` → `1.2.4`         |
| `dont-release` | No tag, nothing publishes |

Exactly one is required; CI blocks the PR until one is set. The release workflow
then builds `linux/amd64` + `linux/arm64`, pushes to GHCR, and signs and attests
as described above.

## Using with GitHub ARC

In your `values.yaml` for the Actions Runner Controller:

```yaml
template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/yourusername/github-runner-base:latest
        # Or use a specific version
        # image: ghcr.io/yourusername/github-runner-base:v1.0.0
```

Or in your `RunnerDeployment` or `RunnerSet`:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: example-runner
spec:
  template:
    spec:
      image: ghcr.io/yourusername/github-runner-base:latest
```

## Testing Locally

```bash
just test     # assert every expected tool is present
just shell    # poke around interactively
just inspect  # image size and layer history
```

## Troubleshooting

### Setup actions still failing?

If setup actions are still failing, check:

1. **Network connectivity**: Ensure your runners can reach GitHub and external
   download URLs
2. **Disk space**: Some setup actions download large files
3. **Permissions**: The image maintains the `runner` user - ensure your ARC
   configuration doesn't override this

### Checking what's in the image

```bash
just sbom
jq -r '.packages[].name' sbom.spdx.json
```

### Common issues

**Issue**: `setup-go` fails with "tar: command not found" **Solution**: This
image includes tar - make sure you're using this image and not the base one

**Issue**: Runner fails to start in ARC **Solution**: Check that you're not
overriding the entrypoint or user in your ARC configuration

## License

MIT License - see LICENSE file for details
