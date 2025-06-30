# syntax=docker/dockerfile:1-labs
FROM debian:latest

COPY . /build
WORKDIR /build

# Build binary package
RUN ./docker_build.sh