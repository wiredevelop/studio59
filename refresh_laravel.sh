#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/backend"

cd "$APP_DIR"

echo "[refresh] Clearing caches..."
php artisan optimize:clear
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan event:clear || true

echo "[refresh] Running migrations..."
php artisan migrate --force

echo "[refresh] Ensuring storage link..."
php artisan storage:link || true

echo "[refresh] Restarting queue workers (if any)..."
php artisan queue:restart || true

echo "[refresh] Done."
