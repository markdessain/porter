# Build stage - using Debian Bookworm for DuckDB compatibility
FROM golang:1.24-bookworm AS builder

# Build arguments
ARG VERSION=dev
ARG COMMIT_HASH=unknown
ARG BUILD_DATE=unknown

# Set working directory
WORKDIR /app

# Install essential build dependencies for DuckDB
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    make \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Set build environment
ENV CGO_ENABLED=1
ENV GOOS=linux
ENV VERSION=${VERSION}
ENV COMMIT_HASH=${COMMIT_HASH}
ENV BUILD_DATE=${BUILD_DATE}

# Build using go directly to avoid make complications
RUN mkdir -p build/bin && \
    go build \
    -v \
    -ldflags "-w -s \
    -X 'github.com/TFMV/porter/cmd/server.version=${VERSION}' \
    -X 'github.com/TFMV/porter/cmd/server.commit=${COMMIT_HASH}' \
    -X 'github.com/TFMV/porter/cmd/server.buildDate=${BUILD_DATE}'" \
    -o build/bin/porter \
    ./cmd/server

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN groupadd -g 1001 porter && \
    useradd -u 1001 -g porter porter

WORKDIR /app

# Copy binary
COPY --from=builder /app/build/bin/porter /usr/local/bin/porter

# Create data directory
RUN mkdir -p /app/data && chown -R porter:porter /app
RUN mkdir -p /home/porter && chown -R porter:porter /home/porter

USER porter

EXPOSE 32010 9090

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD porter --help > /dev/null || exit 1

ENTRYPOINT ["porter"]
CMD ["serve"]