# syntax=docker/dockerfile:1
FROM ghcr.io/actions/actions-runner:2.329.0
RUN sudo apt-get update && sudo apt-get install -y wget curl unzip git
RUN sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*
