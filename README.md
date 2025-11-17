# GitHub Runner Base Image

A custom GitHub Actions runner image that extends the official `ghcr.io/actions/actions-runner:latest` with additional utilities required for common setup actions.

## Why This Image?

The official GitHub Actions runner image is minimal and lacks some tools required by popular setup actions like:
- `actions/setup-go`
- `actions/setup-node`
- `actions/setup-python`
- And many others

This image adds those dependencies while maintaining full compatibility with GitHub's Actions Runner Controller (ARC) for Kubernetes.

## What's Included

This image adds the following tools on top of the official runner:

- **Download utilities**: `curl`, `wget`
- **Archive tools**: `tar`, `gzip`, `bzip2`, `xz-utils`, `unzip`, `zip`
- **Build tools**: `build-essential` (gcc, g++, make)
- **Utilities**: `jq`, `git`, `ca-certificates`, `gnupg`

## Building the Image

```bash
docker build -t ghcr.io/yourusername/github-runner-base:latest .
```

## Pushing to GitHub Container Registry

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Tag the image
docker tag ghcr.io/yourusername/github-runner-base:latest ghcr.io/yourusername/github-runner-base:v1.0.0

# Push
docker push ghcr.io/yourusername/github-runner-base:latest
docker push ghcr.io/yourusername/github-runner-base:v1.0.0
```

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

You can test the image locally to ensure it works:

```bash
# Build the image
docker build -t github-runner-test .

# Run interactively to inspect
docker run -it --rm github-runner-test /bin/bash

# Test that tools are available
docker run --rm github-runner-test bash -c "curl --version && tar --version && git --version"
```

## Troubleshooting

### Setup actions still failing?

If setup actions are still failing, check:

1. **Network connectivity**: Ensure your runners can reach GitHub and external download URLs
2. **Disk space**: Some setup actions download large files
3. **Permissions**: The image maintains the `runner` user - ensure your ARC configuration doesn't override this

### Checking what's in the image

```bash
docker run --rm github-runner-test dpkg -l
```

### Common issues

**Issue**: `setup-go` fails with "tar: command not found"
**Solution**: This image includes tar - make sure you're using this image and not the base one

**Issue**: Runner fails to start in ARC
**Solution**: Check that you're not overriding the entrypoint or user in your ARC configuration

## License

MIT License - see LICENSE file for details
