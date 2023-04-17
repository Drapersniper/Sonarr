FROM cr.hotio.dev/hotio/sonarr:v4
EXPOSE 8989
VOLUME ["${CONFIG_DIR}"]


ARG VERSION
ARG SBRANCH
ARG PACKAGE_VERSION=${VERSION}
RUN rm -r "${APP_DIR}/bin" && \
    mkdir -p "${APP_DIR}/bin"
COPY _output/net6.0/linux-x64/ /app/bin
COPY _output/UI /app/bin/UI
RUN echo -e "PackageVersion=${PACKAGE_VERSION}\nPackageAuthor=[Draper](https://hub.docker.com/r/drapersniper/sonarr)\nUpdateMethod=Docker\nBranch=${SBRANCH}" > "${APP_DIR}/package_info" && \
    chmod -R u=rwX,go=rX "${APP_DIR}" && \
    chmod +x "${APP_DIR}/bin/Sonarr" "${APP_DIR}/bin/ffprobe"
COPY root/ /
RUN chmod -R +x /etc/cont-init.d/ /etc/services.d/
