ARG BASE_IMAGE=debian:trixie
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# Build-Depends from debian/control + packaging tooling: dch writes the
# changelog for each build, lintian gates the result.
# apt lists kept so a Build-Depends added later can still be satisfied with
# `apt-get build-dep` / `mk-build-deps` without an extra `apt-get update`.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      build-essential debhelper cmake \
      qtwebengine5-dev \
      devscripts lintian
