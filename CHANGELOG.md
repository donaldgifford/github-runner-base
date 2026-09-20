# Changelog

All notable changes to this project are documented here. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.1] - 2026-09-20

### Bug Fixes

- Normalise the git tag to the image tag in just verify
- Actually exclude the generated CHANGELOG from markdownlint

## [0.1.0] - 2026-09-20

### Features

- Sign and attest release images with SBOM and provenance
- Scan images on every PR and report to code scanning

### Documentation

- Document the just workflow and supply chain

### Miscellaneous Tasks

- Pin runner base image to an immutable digest
- Replace Makefile with justfile and pin the toolchain
- Clean up copy-pasted repo config and templates

## [0.0.1] - 2026-04-04

### Features

- Add Docker Bake for build management
- Split CI/release workflows and adopt established bake pattern

### Miscellaneous Tasks

- Add CLAUDE.md, claude settings, and renovate config
- Add repo tooling and linter configs

