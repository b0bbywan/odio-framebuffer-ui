ARG BASE_IMAGE=debian:trixie
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# Compile deps of upstream's kiosk build (main.cpp + mainwindow.cpp against
# Qt 5 WebEngine) + what scripts/build-deb.sh needs to stage and package it.
# qtwebengine5-dev pulls qtbase5-dev, which carries the cmake configs.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      cmake make g++ pkg-config \
      qtwebengine5-dev \
      dpkg-dev binutils file \
 && rm -rf /var/lib/apt/lists/*
