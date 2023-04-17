FROM cr.hotio.dev/hotio/sonarr:v4
EXPOSE 8989
VOLUME ["${CONFIG_DIR}"]


ARG VERSION
ARG SBRANCH
ARG PACKAGE_VERSION=${VERSION}
COPY _output/net6.0/linux-x64/ /app/bin
RUN mkdir -p "${APP_DIR}/bin" && \
    rm -rf "${APP_DIR}/bin/Sonarr.Update" && \
    echo -e "PackageVersion=${PACKAGE_VERSION}\nPackageAuthor=[hotio](https://github.com/hotio)\nUpdateMethod=Docker\nBranch=${SBRANCH}" > "${APP_DIR}/package_info" && \
    chmod -R u=rwX,go=rX "${APP_DIR}" && \
    chmod +x "${APP_DIR}/bin/Sonarr" "${APP_DIR}/bin/ffprobe"
COPY root/ /
RUN chmod -R +x /etc/cont-init.d/ /etc/services.d/
