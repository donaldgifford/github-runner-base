variable "REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAME" {
  default = "donaldgifford/github-runner-base"
}

variable "TAGS" {
  # Comma-separated list of tags; CI overrides this via metadata-action.
  default = "${REGISTRY}/${IMAGE_NAME}:latest"
}

variable "LABELS" {
  default = ""
}

variable "CACHE_FROM" {
  default = ""
}

variable "CACHE_TO" {
  default = ""
}

function "parse_tags" {
  params = [tags]
  result = split("\n", tags)
}

group "default" {
  targets = ["runner"]
}

target "runner" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = parse_tags(TAGS)
  labels     = LABELS != "" ? { for pair in split("\n", LABELS) : element(split("=", pair), 0) => element(split("=", pair), 1) if pair != "" } : {}
}

target "local" {
  inherits = ["runner"]
  tags     = ["${REGISTRY}/${IMAGE_NAME}:local"]
  output   = ["type=docker"]
}

target "test" {
  inherits = ["runner"]
  tags     = ["${REGISTRY}/${IMAGE_NAME}:test"]
  output   = ["type=docker"]
}

target "ci" {
  inherits = ["runner"]
  cache-from = CACHE_FROM != "" ? [CACHE_FROM] : []
  cache-to   = CACHE_TO != "" ? [CACHE_TO] : []
}

target "ci-local" {
  inherits   = ["ci"]
  platforms  = ["linux/amd64"]
  output     = ["type=docker"]
}

target "ci-push" {
  inherits   = ["ci"]
  platforms  = ["linux/amd64", "linux/arm64"]
  output     = ["type=registry"]
}
