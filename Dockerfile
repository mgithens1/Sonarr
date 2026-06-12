FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# Install Node.js + yarn for frontend
RUN apt-get update && apt-get install -y --no-install-recommends git curl gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

COPY . .

# Build backend - linux-x64 only
RUN dotnet msbuild -restore src/Sonarr.sln -p:Configuration=Release -p:Platform=Posix -p:RuntimeIdentifiers=linux-x64 -t:PublishAllRids

# Build frontend
RUN cd frontend && yarn install --network-timeout 120000 && yarn run build --env production

# Runtime
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    icu-devtools \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/_output/net6.0/linux-x64/publish /opt/sonarr/bin
COPY --from=build /src/_output/UI /opt/sonarr/bin/UI

RUN mkdir -p /config && chown -R 99:100 /config /opt/sonarr

EXPOSE 8989
USER 99
ENTRYPOINT ["/opt/sonarr/bin/Sonarr", "-data=/config", "-nobrowser"]