# Build stage - using Debian instead of Alpine for better DuckDB compatibility
FROM golang:1.24-bullseye AS builder

# Build arguments
ARG VERSION=dev
ARG COMMIT_HASH=unknown
ARG BUILD_DATE=unknown

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    make \
    gcc \
    g++ \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application with version information
ENV VERSION=${VERSION}
ENV COMMIT_HASH=${COMMIT_HASH}
ENV BUILD_DATE=${BUILD_DATE}
ENV CGO_ENABLED=1
RUN make build

# Final stage - using Debian slim for glibc compatibility
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1001 porter && \
    useradd -u 1001 -g porter -s /bin/sh porter

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/build/bin/porter /usr/local/bin/porter

# Copy config files
COPY --from=builder /app/config/ ./config/

# Change ownership
RUN chown -R porter:porter /app

# Switch to non-root user
USER porter

# Expose ports
EXPOSE 32010 9090

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD porter --help > /dev/null || exit 1

# Set entrypoint
ENTRYPOINT ["porter"]
CMD ["serve"]