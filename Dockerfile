# Build stage
FROM golang:1.24-alpine AS builder

# Build arguments
ARG VERSION=dev
ARG COMMIT_HASH=unknown
ARG BUILD_DATE=unknown

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git make gcc g++ musl-dev

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
RUN make build

# Final stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1001 -S porter && \
    adduser -u 1001 -S porter -G porter

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