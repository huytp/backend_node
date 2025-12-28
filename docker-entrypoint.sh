#!/bin/bash
set -e

# Create necessary directories
mkdir -p tmp/pids tmp/cache tmp/sockets log

# Wait for PostgreSQL to be ready
if [ -n "$POSTGRES_HOST" ]; then
  echo "Waiting for PostgreSQL to be ready..."
  until pg_isready -h "$POSTGRES_HOST" -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-postgres}"; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 2
  done
  echo "PostgreSQL is ready!"
fi

# Run database migrations if needed (only for web service)
if [ "$1" = "bundle" ] && [ "$2" = "exec" ] && [ "$3" = "puma" ]; then
  echo "Running database migrations..."
  bundle exec rails db:migrate || true
fi

# Execute the main command
exec "$@"

