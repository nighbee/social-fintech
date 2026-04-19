# Production Dockerfile
FROM golang:1.24-alpine AS builder

WORKDIR /app
# Install build dependencies for CGO (required by H3)
RUN apk add --no-cache git gcc musl-dev libc-dev make

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build API and Worker binaries with CGO enabled
RUN CGO_ENABLED=1 GOOS=linux go build -o main-api ./cmd/api
RUN CGO_ENABLED=1 GOOS=linux go build -o main-worker ./cmd/worker

FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata curl
# Required for CGO binaries to run on Alpine
RUN apk add --no-cache libc6-compat

WORKDIR /root/

COPY --from=builder /app/main-api ./api
COPY --from=builder /app/main-worker ./worker
COPY --from=builder /app/config.yaml .
COPY --from=builder /app/migrations ./migrations

EXPOSE 8080

# Default to api, can be overridden in docker-compose
CMD ["./api"]
