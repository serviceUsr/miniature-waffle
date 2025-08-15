ARG CONTAINER=ghcr.io/openwrt/imagebuilder
ARG ARCH=mediatek-filogic
FROM $CONTAINER:$ARCH

LABEL "com.github.actions.name"="OpenWrt ImageBuilder"

ADD entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
