# Dev target: interpreted dart run (debug compose + volume-mount friendly)
FROM dart:stable AS dev
RUN apt-get update && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY bin ./bin
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -sf http://127.0.0.1:8080/health || exit 1
CMD ["dart", "run", "bin/app.dart"]

# Prod target: compiled binary
FROM dev AS build
RUN dart compile exe bin/app.dart -o server

FROM debian:bookworm-slim AS prod
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/server ./server
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -sf http://127.0.0.1:8080/health || exit 1
CMD ["./server"]
