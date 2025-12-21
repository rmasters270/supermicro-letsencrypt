FROM goacme/lego:v4.25.2
RUN apk add --no-cache ca-certificates bash openssl python3-dev py3-pip py3-openssl py3-lxml py3-requests py3-urllib3 \
    && adduser -u 1000 -D  lego \
    && mkdir -p /home/lego/.lego \
    && chown -R 1000:1000 /home/lego

USER 1000

WORKDIR /home/lego

ADD entrypoint.sh le-supermicro-ipmi.sh supermicro-ipmi-updater.py /home/lego/

ENTRYPOINT ["/home/lego/entrypoint.sh"]
