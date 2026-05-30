FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends git curl gnupg && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y --no-install-recommends yarn && \
    rm -rf /var/lib/apt/lists/*

# Copy everything including .git for version detection
COPY . .

# Build backend using Sonarr's own build system
RUN dotnet msbuild -restore src/Sonarr.sln -p:Configuration=Release -p:Platform=Posix -t:PublishAllRids

# Build frontend
RUN cd frontend && yarn install --frozen-lockfile --network-timeout 120000 && yarn run build --env production

# Runtime image
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    icu-devtools \
    && rm -rf /var/lib/apt/lists/*

# Copy backend output
COPY --from=build /src/_output/net6.0/linux-x64/publish /opt/sonarr/bin
# Copy frontend output
COPY --from=build /src/_output/UI /opt/sonarr/bin/UI

RUN mkdir -p /config && chown -R 99:100 /config /opt/sonarr

EXPOSE 8989
USER 99
ENTRYPOINT ["/opt/sonarr/bin/Sonarr", "-data=/config", "-nobrowser"]