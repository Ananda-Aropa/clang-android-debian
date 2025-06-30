# syntax=docker/dockerfile:1-labs
FROM debian:latest

COPY . /build
WORKDIR /build

# Build binary package
RUN --mount=type=bind,source=.,target=/build ./docker_build.sh