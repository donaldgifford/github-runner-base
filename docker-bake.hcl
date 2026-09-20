// docker-bake.hcl — Docker image builds for github-runner-base.
//
// Targets:
//   dev     — native single-arch build, loaded into the local Docker daemon
//   ci      — linux/amd64 build, loaded into the daemon so PR CI can scan it
//   release — multi-arch build, pushed to the registry with SBOM + provenance
//
// Cache backends are deliberately NOT declared here. `type=gha` only works
// inside GitHub Actions, so baking it into the targets would break every
// local `just docker-build`. CI layers it on via `--set *.cache-from=...`.

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAME" {
  default = "donaldgifford/github-runner-base"
}

variable "VERSION" {
  default = "dev"
}

variable "COMMIT_SHA" {
  default = ""
}

variable "BUILD_DATE" {
  default = ""
}

target "_common" {
  dockerfile = "Dockerfile"
  context    = "."
  labels = {
    "org.opencontainers.image.source"      = "https://github.com/donaldgifford/github-runner-base"
    "org.opencontainers.image.description" = "GitHub Actions Runner with extended tooling for setup actions"
    "org.opencontainers.image.licenses"    = "MIT"
    "org.opencontainers.image.revision"    = "${COMMIT_SHA}"
    "org.opencontainers.image.created"     = "${BUILD_DATE}"
    "org.opencontainers.image.version"     = "${VERSION}"
  }
}

// No platforms pin — local builds target the host platform so the image
// actually runs on both Apple Silicon and amd64 workstations.
target "dev" {
  inherits = ["_common"]
  tags     = ["${REGISTRY}/${IMAGE_NAME}:dev"]
  output   = ["type=docker"]
}

// PR validation build. linux/amd64 only and loaded into the daemon: emulated
// arm64 builds via QEMU dominate PR feedback time, and the vulnerability scan
// needs a concrete single-platform image in the local image store. Multi-arch
// coverage is restored by the release target.
target "ci" {
  inherits  = ["_common"]
  tags      = ["${REGISTRY}/${IMAGE_NAME}:ci"]
  platforms = ["linux/amd64"]
  output    = ["type=docker"]
}

// Stub providing default tags for a local `docker buildx bake release`. The
// release workflow overrides this target wholesale with docker/metadata-action's
// bake-file-tags output. `release` inherits from it and declares no tags of its
// own — with HCL inheritance a child's tags list *replaces* the parent's, so
// declaring them here is what lets the CI override take effect.
target "docker-metadata-action" {
  tags = ["${REGISTRY}/${IMAGE_NAME}:${VERSION}"]
}

target "release" {
  inherits  = ["_common", "docker-metadata-action"]
  platforms = ["linux/amd64", "linux/arm64"]
  output    = ["type=registry"]
  // In-registry supply-chain metadata: an SPDX SBOM and max-detail SLSA
  // provenance are pushed as OCI attestation manifests in the same index as
  // the image, readable via `docker buildx imagetools inspect`. The release
  // workflow additionally publishes Sigstore-signed GitHub attestations and a
  // cosign signature over the resulting index digest.
  attest = [
    "type=provenance,mode=max",
    "type=sbom",
  ]
}
