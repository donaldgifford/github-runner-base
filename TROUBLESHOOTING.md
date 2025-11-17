# Troubleshooting Guide

Common issues and solutions when using this custom runner image with GitHub ARC.

## Table of Contents

- [Build Issues](#build-issues)
- [Runner Registration Issues](#runner-registration-issues)
- [Setup Action Failures](#setup-action-failures)
- [Performance Issues](#performance-issues)
- [ARC-Specific Issues](#arc-specific-issues)

## Build Issues

### Issue: Docker build fails with network timeout

**Symptoms:**
```
E: Failed to fetch http://archive.ubuntu.com/ubuntu/...
```

**Solutions:**
1. Check your network connectivity
2. Try building with `--network=host` flag:
   ```bash
   docker build --network=host -t github-runner-base .
   ```
3. Use a different apt mirror by adding to Dockerfile before apt-get update:
   ```dockerfile
   RUN sed -i 's/archive.ubuntu.com/mirror.example.com/g' /etc/apt/sources.list
   ```

### Issue: Build fails with "runner user not found"

**Symptoms:**
```
Error: user runner not found
```

**Solution:**
This means the base image changed. Check the official runner image and verify the user name:
```bash
docker run --rm ghcr.io/actions/actions-runner:latest id
```

## Runner Registration Issues

### Issue: Runner fails to register with GitHub

**Symptoms:**
- Pods in CrashLoopBackOff
- Logs show authentication errors

**Solutions:**
1. Verify your GitHub token/app credentials:
   ```bash
   kubectl get secret github-runner-secret -n actions-runner-system -o yaml
   ```

2. Check token permissions:
   - For repos: `repo` scope
   - For orgs: `admin:org` scope

3. Verify the githubConfigUrl is correct:
   ```bash
   kubectl describe runnerdeployment -n actions-runner-system
   ```

### Issue: Runners registered but don't pick up jobs

**Symptoms:**
- Runners show as "Idle" in GitHub UI
- Jobs stay in "Queued" state

**Solutions:**
1. Check runner labels match your workflow:
   ```yaml
   runs-on: [self-hosted, linux, extended-tools]
   ```

2. Verify runner has network access to GitHub:
   ```bash
   kubectl exec -it <runner-pod> -- curl -I https://github.com
   ```

## Setup Action Failures

### Issue: `setup-go` fails with "tar: command not found"

**Symptoms:**
```
Error: Unable to extract Go: tar: command not found
```

**Solution:**
This should be fixed by this image! Verify you're using the correct image:
```bash
kubectl get pods -n actions-runner-system -o jsonpath='{.items[*].spec.containers[*].image}'
```

### Issue: `setup-node` fails with download errors

**Symptoms:**
```
Error: Unable to download Node.js
```

**Solutions:**
1. Check network connectivity from runner:
   ```bash
   kubectl exec -it <runner-pod> -- curl -I https://nodejs.org
   ```

2. Verify curl is installed:
   ```bash
   kubectl exec -it <runner-pod> -- which curl
   ```

### Issue: `setup-python` fails during build

**Symptoms:**
```
Error: Could not build Python from source
```

**Solution:**
This image includes `build-essential`. If still failing, you may need additional libraries:
```dockerfile
# Add to Dockerfile after the existing apt-get install
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

## Performance Issues

### Issue: Slow job startup times

**Symptoms:**
- Jobs take several minutes to start
- High "Queued" times

**Solutions:**
1. Pre-pull the image on nodes:
   ```yaml
   # In your values.yaml
   image:
     pullPolicy: IfNotPresent
   ```

2. Use ImagePullSecrets if using private registry:
   ```yaml
   imagePullSecrets:
     - name: ghcr-secret
   ```

3. Increase runner pool:
   ```yaml
   minRunners: 3
   maxRunners: 10
   ```

### Issue: Jobs failing with "disk space" errors

**Symptoms:**
```
Error: No space left on device
```

**Solutions:**
1. Increase ephemeral storage:
   ```yaml
   resources:
     limits:
       ephemeral-storage: "10Gi"
   ```

2. Add cleanup in your workflows:
   ```yaml
   - name: Cleanup
     if: always()
     run: |
       docker system prune -af
       rm -rf $GITHUB_WORKSPACE/*
   ```

## ARC-Specific Issues

### Issue: Runners don't scale

**Symptoms:**
- Only minimum number of runners ever created
- Jobs queue even with maxRunners not reached

**Solutions:**
1. Check HPA (Horizontal Pod Autoscaler) status:
   ```bash
   kubectl get hpa -n actions-runner-system
   ```

2. Verify metrics server is running:
   ```bash
   kubectl get deployment metrics-server -n kube-system
   ```

3. Check ARC controller logs:
   ```bash
   kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller
   ```

### Issue: Image pull errors

**Symptoms:**
```
Failed to pull image "ghcr.io/donaldgifford/github-runner-base:latest": rpc error: code = Unknown
```

**Solutions:**
1. Verify image exists and is public/accessible:
   ```bash
   docker pull ghcr.io/donaldgifford/github-runner-base:latest
   ```

2. Create imagePullSecret if private:
   ```bash
   kubectl create secret docker-registry ghcr-secret \
     --docker-server=ghcr.io \
     --docker-username=$GITHUB_USER \
     --docker-password=$GITHUB_TOKEN \
     -n actions-runner-system
   ```

3. Reference in your deployment:
   ```yaml
   spec:
     template:
       spec:
         imagePullSecrets:
           - name: ghcr-secret
   ```

### Issue: Runner pod stuck in pending

**Symptoms:**
- Pods show "Pending" status
- Never transition to "Running"

**Solutions:**
1. Check events:
   ```bash
   kubectl describe pod <runner-pod> -n actions-runner-system
   ```

2. Common causes:
   - Insufficient resources: Reduce resource requests
   - Node selector mismatch: Check node labels
   - PVC issues: Verify storage class exists

## Debugging Tips

### Get runner logs
```bash
kubectl logs <runner-pod> -n actions-runner-system
```

### Exec into runner
```bash
kubectl exec -it <runner-pod> -n actions-runner-system -- /bin/bash
```

### Check installed packages
```bash
kubectl exec <runner-pod> -n actions-runner-system -- dpkg -l
```

### Test setup action manually
```bash
kubectl exec -it <runner-pod> -n actions-runner-system -- bash
# Inside the pod:
curl -LO https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
tar -C /tmp -xzf go1.21.0.linux-amd64.tar.gz
```

## Still Having Issues?

1. Check the [GitHub ARC documentation](https://github.com/actions/actions-runner-controller)
2. Review [GitHub Actions runner requirements](https://docs.github.com/en/actions/hosting-your-own-runners)
3. Open an issue in this repository with:
   - Your Dockerfile (if modified)
   - Runner deployment YAML
   - Relevant error logs
   - Steps to reproduce
