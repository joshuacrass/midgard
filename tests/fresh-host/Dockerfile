# Fresh Ubuntu 24.04 host with only the README prerequisites: a sudo user, Git, Python.
# systemd runs as PID 1 so the docker and tailscale steps can enable their services.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends systemd systemd-sysv sudo git python3 ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash -G sudo midgard \
    && echo 'midgard ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/midgard
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
