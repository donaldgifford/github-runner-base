// docker-bake.hcl — Docker image builds for github-runner-base.
//
// Targets:
//   dev     — local single-arch build, loads into Docker daemon
//   ci      — multi-arch validation build, no push
//   release — multi-arch build, pushes to registry

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

function "tags" {
  params = [version]
  result = version == "dev" ? [
    "${REGISTRY}/${IMAGE_NAME}:dev",
    ] : [
    "${REGISTRY}/${IMAGE_NAME}:${version}",
    "${REGISTRY}/${IMAGE_NAME}:latest",
  ]
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

target "dev" {
  inherits = ["_common"]
  tags     = tags("dev")
  output   = ["type=docker"]
}

target "ci" {
  inherits   = ["_common"]
  tags       = tags(VERSION)
  platforms  = ["linux/amd64", "linux/arm64"]
  output     = ["type=cacheonly"]
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}

target "docker-metadata-action" {
  tags = tags(VERSION)
}

target "release" {
  inherits   = ["_common", "docker-metadata-action"]
  platforms  = ["linux/amd64", "linux/arm64"]
  output     = ["type=registry"]
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}
