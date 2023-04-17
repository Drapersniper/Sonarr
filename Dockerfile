ARG UPSTREAM_IMAGE
ARG UPSTREAM_DIGEST_AMD64

FROM ${UPSTREAM_IMAGE}@${UPSTREAM_DIGEST_AMD64}

EXPOSE 8989
VOLUME ["${CONFIG_DIR}"]

RUN apk add --no-cache libintl sqlite-libs icu-libs


ARG VERSION
ARG SBRANCH
ARG PACKAGE_VERSION=${VERSION}

RUN mkdir -p "${APP_DIR}/bin"
COPY _artifacts/linux-x64/net6.0/Sonarr /app/bin
RUN  rm -rf "${APP_DIR}/bin/Sonarr.Update" && \
     echo -e "PackageVersion=${VERSION}\nPackageAuthor=[Draper](https://hub.docker.com/r/drapersniper/sonarr)\nUpdateMethod=Docker\nBranch=${SBRANCH}" > "${APP_DIR}/package_info" && \
    chmod -R u=rwX,go=rX "${APP_DIR}" && \
    chmod +x "${APP_DIR}/bin/Sonarr" "${APP_DIR}/bin/ffprobe"

ARG ARR_DISCORD_NOTIFIER_VERSION
RUN curl -fsSL "https://raw.githubusercontent.com/hotio/arr-discord-notifier/${ARR_DISCORD_NOTIFIER_VERSION}/arr-discord-notifier.sh" > "${APP_DIR}/arr-discord-notifier.sh" && \
    chmod u=rwx,go=rx "${APP_DIR}/arr-discord-notifier.sh"

COPY root/root/ /
RUN chmod -R +x /etc/cont-init.d/ /etc/services.d/