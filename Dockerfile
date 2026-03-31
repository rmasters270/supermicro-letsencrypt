ARG SUPERCRONIC_VERSION=v0.2.41

# Builder: download supercronic
FROM alpine:3.23 AS supercronic
ARG TARGETARCH
ARG SUPERCRONIC_VERSION

RUN apk add --no-cache curl \
 && curl -fsSL \
    https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH} \
    -o /supercronic \
 && chmod +x /supercronic


# Runtime: lego
FROM goacme/lego:v4.30.1

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

RUN apk add --no-cache ca-certificates bash openssl python3-dev py3-pip py3-openssl py3-lxml py3-requests py3-urllib3 \
    && adduser -u 1000 -D lego \
    && mkdir -p /home/lego/.lego \
    && chown -R 1000:1000 /home/lego

ADD entrypoint.sh le-supermicro-ipmi.sh supermicro-ipmi-updater.py /home/lego/
RUN chmod +x /home/lego/entrypoint.sh /home/lego/le-supermicro-ipmi.sh

USER 1000
WORKDIR /home/lego

ENTRYPOINT ["/home/lego/entrypoint.sh"]

HEALTHCHECK \
  --interval=1h \
  --timeout=10s \
  --retries=3 \
  --start-period=2m \
  CMD test -f /tmp/last-run && \
      [ $(( $(date +%s) - $(cat /tmp/last-run) )) -lt 900000 ] || exit 1
