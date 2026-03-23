FROM alpine:3.21 AS downloader

ARG TELEMT_VERSION=3.3.28

RUN apk add --no-cache wget ca-certificates \
    && wget -O /tmp/telemt.tar.gz \
        "https://github.com/telemt/telemt/releases/download/${TELEMT_VERSION}/telemt-x86_64-linux-musl.tar.gz" \
    && tar -xzf /tmp/telemt.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/telemt

# musl-linked бинарь запускается в alpine без зависимостей
FROM alpine:3.21
COPY --from=downloader /usr/local/bin/telemt /usr/local/bin/telemt
ENTRYPOINT ["telemt"]

