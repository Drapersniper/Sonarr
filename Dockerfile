# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.17

# set version label
ARG BUILD_DATE
ARG VERSION
ARG SONARR_VERSION
ARG SONARR_HASH
LABEL build_version="Draper version:- ${SONARR_HASH} Build-date:- ${BUILD_DATE}"
LABEL maintainer="Drapersniper"

# set environment variables
ENV XDG_CONFIG_HOME="/config/xdg"
ENV SONARR_BRANCH="v4"
RUN mkdir -p /app/sonarr/bin
COPY _artifacts/linux-x64/net6.0/Sonarr /app/sonarr/bin
RUN \
  echo "**** install packages ****" && \
  apk add -U --upgrade --no-cache \
    icu-libs \
    sqlite-libs && \
  echo -e "UpdateMethod=docker\nBranch=${SONARR_BRANCH}\nPackageVersion=${VERSION}+${SONARR_HASH}\nPackageAuthor=[Draper](https://hub.docker.com/r/drapersniper/sonarr)" > /app/sonarr/package_info && \
  echo "**** cleanup ****" && \
  rm -rf \
    /app/sonarr/bin/Sonarr.Update \
    /tmp/*

# add local files
COPY linuxserver/root/ /

# ports and volumes
EXPOSE 8989

VOLUME /config
