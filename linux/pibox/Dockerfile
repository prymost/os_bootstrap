# pibox — general-purpose agentic coding environment based on Debian Bookworm Slim
# Build once, reuse for any project via the `pibox` shell function.

# Copy node from the official lightweight image to avoid network issues
FROM node:lts-bookworm-slim AS node-source

FROM debian:bookworm-slim

ARG USERNAME=agent
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# --- Base toolchain -----------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        build-essential \
        pkg-config \
        libssl-dev \
        unzip \
        jq \
        ripgrep \
        vim \
        less \
    && rm -rf /var/lib/apt/lists/*

# --- Python ---------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# --- Ruby -------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ruby-full \
    && rm -rf /var/lib/apt/lists/*

# --- Go -----------------------------------------------------------------
ADD https://go.dev/dl/?mode=json /tmp/go-version.json
RUN ARCH=$(dpkg --print-architecture) \
    && GO_VERSION=$(jq -r '.[0].version' /tmp/go-version.json | sed 's/go//') \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# --- Node.js (copied from official source) -------------------------------
COPY --from=node-source /usr/local/bin/node /usr/local/bin/
COPY --from=node-source /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# --- Kubernetes CLI (kubectl) --------------------------------------------
ADD https://dl.k8s.io/release/stable.txt /tmp/kubectl-stable.txt
RUN ARCH=$(dpkg --print-architecture) \
    && KUBECTL_VERSION=$(cat /tmp/kubectl-stable.txt) \
    && curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    && chmod +x /usr/local/bin/kubectl




# --- Non-root user --------------------------------------------------------
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}

# Give the user their own writable dirs for language package caches
# (pip cache, gem home, go path) so nothing needs to write outside $HOME.
ENV GEM_HOME=/home/${USERNAME}/.gem
ENV GOPATH=/home/${USERNAME}/go
ENV PATH="${GEM_HOME}/bin:${GOPATH}/bin:${PATH}"

# --- pi.dev ---------------------------------------------------------------
# Invalidate docker build cache only when a new version of the package is published
ADD "https://registry.npmjs.org/@earendil-works/pi-coding-agent/latest" /tmp/pi-version.json
RUN npm install -g @earendil-works/pi-coding-agent

# Ensure home dir and config folders are writable by dynamic user IDs
RUN mkdir -p /home/${USERNAME}/.pi \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} \
    && chmod -R 777 /home/${USERNAME}

USER ${USERNAME}
WORKDIR /workspace

ENTRYPOINT ["pi"]
