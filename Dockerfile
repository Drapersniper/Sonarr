FROM cr.hotio.dev/hotio/sonarr:v4

EXPOSE 8989
VOLUME ["${CONFIG_DIR}"]

RUN apk add --no-cache libintl sqlite-libs icu-libs


ARG VERSION
ARG SBRANCH
ARG PACKAGE_VERSION=${VERSION}

RUN mkdir -p "${APP_DIR}/bin"

RUN rm /app/bin/Sonarr.Core.dll /app/bin/Sonarr.Core.pdb /app/bin/Sonarr.Core.deps.json

COPY _artifacts/linux-x64/net6.0/Sonarr/Sonarr.Core.dll /app/bin/Sonarr.Core.dll
COPY _artifacts/linux-x64/net6.0/Sonarr/Sonarr.Core.pdb /app/bin/Sonarr.Core.pdb
COPY _artifacts/linux-x64/net6.0/Sonarr/Sonarr.Core.deps.json /app/bin/Sonarr.Core.deps.json

ARG ARR_DISCORD_NOTIFIER_VERSION
RUN curl -fsSL "https://raw.githubusercontent.com/hotio/arr-discord-notifier/${ARR_DISCORD_NOTIFIER_VERSION}/arr-discord-notifier.sh" > "${APP_DIR}/arr-discord-notifier.sh" && \
    chmod u=rwx,go=rx "${APP_DIR}/arr-discord-notifier.sh"

COPY root/root/ /
RUN chmod -R +x /etc/cont-init.d/ /etc/services.d/