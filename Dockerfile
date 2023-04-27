FROM randomninjaatk/sonarr-extended:latest

EXPOSE 8989

ARG VERSION
ARG SBRANCH
ARG PACKAGE_VERSION=${VERSION}
ARG PACKAGE_HASH
ENV APP_DIR="/app/sonarr"

RUN rm -rf "${APP_DIR}/bin" && \
    mkdir -p "${APP_DIR}/bin"

COPY _artifacts/linux-musl-x64/net6.0/Sonarr /app/sonarr/bin/
  
RUN rm -rf "${APP_DIR}/bin/Sonarr.Update" && \
    echo -e "PackageVersion=${PACKAGE_VERSION}+${PACKAGE_HASH}\nPackageAuthor=[Draper](https://hub.docker.com/r/drapersniper/sonarr)\nUpdateMethod=Docker\nBranch=${SBRANCH}" > "${APP_DIR}/package_info" && \
    chmod -R u=rwX,go=rX "${APP_DIR}" && \
    chmod +x "${APP_DIR}/bin/Sonarr" "${APP_DIR}/bin/ffprobe" 
