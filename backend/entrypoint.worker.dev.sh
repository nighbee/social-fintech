#!/bin/sh
set -e

echo "==> Building migrate tool..."
go build -o /tmp/migrate ./cmd/migrate

echo "==> Running database migrations..."
until /tmp/migrate; do
    echo "    DB not ready yet, retrying in 3 seconds..."
    sleep 3
done
echo "==> Migrations complete. Starting worker..."

exec air -c .air.worker.toml
