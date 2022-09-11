FROM cr.hotio.dev/hotio/sonarr:nightly


EXPOSE 8989

ENV VERSION=4.0.0.104
ENV SBRANCH=develop
ENV PACKAGE_VERSION=${VERSION}
ENV ARR_DISCORD_NOTIFIER_VERSION=0.0.35


ADD _artifacts/linux-x64/net6.0/Sonarr ${APP_DIR}/bin/

RUN rm -rf "${APP_DIR}/bin/Sonarr.Update" && \
    echo -e "PackageVersion=${PACKAGE_VERSION}\nPackageAuthor=[Draper](https://github.com/Drapersniper/Sonarr)\nUpdateMethod=Docker\nBranch=${SBRANCH}" > "${APP_DIR}/package_info" && \
    chmod -R u=rwX,go=rX "${APP_DIR}"

ARG ARR_DISCORD_NOTIFIER_VERSION
RUN curl -fsSL "https://raw.githubusercontent.com/hotio/arr-discord-notifier/${ARR_DISCORD_NOTIFIER_VERSION}/arr-discord-notifier.sh" > "${APP_DIR}/arr-discord-notifier.sh" && \
    chmod u=rwx,go=rx "${APP_DIR}/arr-discord-notifier.sh"

COPY root/root/ /