## Builder image
FROM ubuntu:22.04 AS builder

ARG GHC_VERSION=8.8.4
ARG STACK_VERSION=2.9.3

ENV LANG=C.UTF-8

WORKDIR /duckling/

# Install system dependencies
# --mount=type=cache,target=/var/cache/apt \
RUN apt-get update -qq && \
    apt-get install -qq -y --fix-missing --no-install-recommends \
        build-essential \
        ca-certificates \
        clang-12 \
        curl \
        libgmp-dev \
        libnuma-dev \
        libnuma1 \
        libpcre3 \
        libpcre3-dev \
        libssl-dev \
        lldb-12 \
        lld-12 \
        pkg-config \
        zlib1g-dev

# Install stack
# https://docs.haskellstack.org/en/stable/
RUN ARCH=$(uname -i) && \
    curl -OJL https://github.com/commercialhaskell/stack/releases/download/v${STACK_VERSION}/stack-${STACK_VERSION}-linux-${ARCH}.tar.gz && \
    tar -xf stack-${STACK_VERSION}-linux-${ARCH}.tar.gz && \
    cd stack-*-linux-${ARCH}/ && \
    chmod +x stack && \
    mv stack /usr/local/bin/ && \
    stack --version

# Install Haskell stack
RUN stack setup \
    --compiler ghc-${GHC_VERSION} \
    --system-ghc

# Build Duckling dependencies
COPY stack.yaml duckling.cabal .

RUN stack build \
    --compiler ghc-${GHC_VERSION} \
    --system-ghc \
    --dependencies-only

# Build Duckling
COPY . .

RUN stack build \
    --compiler ghc-${GHC_VERSION} \
    --system-ghc \
    --test \
    --no-run-tests \
    --copy-bins \
    --local-bin-path /duckling/bin/

# Run Duckling tests
RUN stack test --compiler ghc-${GHC_VERSION} --system-ghc


## Build final image
FROM ubuntu:22.04

ENV LANG C.UTF-8

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata \
 && rm -rf /var/lib/apt/lists/* \
 \
 && groupadd -g 10001 nonroot \
 && useradd -u 10000 -g nonroot nonroot \
 \
 && mkdir /log \
 && chown nonroot:nonroot /log

COPY --from=builder /duckling/bin/duckling-example-exe /app/

USER nonroot:nonroot

EXPOSE 8000

ENTRYPOINT ["/app/duckling-example-exe"]
CMD ["-p", "8000", "--access-log=/dev/stdout", "--error-log=/dev/stderr"]