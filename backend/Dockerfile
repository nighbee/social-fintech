# syntax=docker/dockerfile:1
# Production Dockerfile
FROM golang:1.24-alpine AS base
WORKDIR /app
# Install build dependencies for CGO (required by H3)
RUN apk add --no-cache git gcc musl-dev libc-dev make
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .

# Build API stage
FROM base AS builder-api
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o /main-api ./cmd/api

# Build Worker stage
FROM base AS builder-worker
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o /main-worker ./cmd/worker

# Final runtime image
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata curl libc6-compat
WORKDIR /root/
COPY --from=builder-api /main-api ./api
COPY --from=builder-worker /main-worker ./worker
COPY --from=base /app/config.yaml .
COPY --from=base /app/migrations ./migrations

EXPOSE 8080
CMD ["./api"]
