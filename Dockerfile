ARG BUILD_IMAGE=alpine:3.23
ARG BASE_IMAGE=alpine:3.23

FROM ${BUILD_IMAGE} AS build

ARG APK_MIRROR
RUN if [ -n "$APK_MIRROR" ]; then sed -i "s/dl-cdn.alpinelinux.org/$APK_MIRROR/g" /etc/apk/repositories; fi
RUN apk update && apk add curl make gcc g++ linux-headers openssl-dev openssl-libs-static

ARG RUSTUP_DIST_SERVER
RUN RUSTUP_DIST_SERVER=$RUSTUP_DIST_SERVER curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ARG ZEROTIER_VERSION=1.16.0
ARG HTTPS_PROXY
RUN HTTPS_PROXY=$HTTPS_PROXY curl -fsSL https://github.com/zerotier/ZeroTierOne/archive/refs/tags/${ZEROTIER_VERSION}.tar.gz | tar zxf -
RUN mv /ZeroTierOne-$ZEROTIER_VERSION /zerotier

WORKDIR /zerotier
RUN HTTPS_PROXY=$HTTPS_PROXY LDFLAGS=-static make -j$(nproc)

FROM ${BASE_IMAGE}

COPY --from=build /zerotier/zerotier-one /usr/sbin/
RUN cd /usr/sbin/ && \
    ln -sf zerotier-one zerotier-idtool && \
    ln -sf zerotier-one zerotier-cli

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

HEALTHCHECK --interval=1s CMD bash /healthcheck.sh

CMD []
ENTRYPOINT ["/entrypoint.sh"]
