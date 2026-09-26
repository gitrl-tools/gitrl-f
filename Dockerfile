ARG UBUNTU=24.04
FROM ubuntu:${UBUNTU}

ENV DEBIAN_FRONTEND=noninteractive

COPY debian/control /tmp/gitree/debian/control

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        debhelper \
        devscripts \
        dpkg-dev \
        fakeroot \
        lintian \
    && apt-get build-dep -y /tmp/gitree \
    && rm -rf /var/lib/apt/lists/* /tmp/gitree

RUN apt-get update && apt-get install -y --no-install-recommends \
        adwaita-icon-theme \
        dbus-x11 \
        groff-base \
        librsvg2-common \
        man-db \
        shared-mime-info \
        xauth \
        xdotool \
        xvfb \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/bin/man \
    && dpkg-divert --quiet --remove --rename /usr/bin/man

WORKDIR /src
CMD ["/bin/bash"]
