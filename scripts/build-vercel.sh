#!/usr/bin/env bash
set -e

echo "=== Building Flutter Web for Vercel ==="

# Check if flutter is already in PATH
if ! command -v flutter &> /dev/null; then
  echo "Installing Flutter Linux SDK..."
  FLUTTER_VERSION="3.29.0"
  curl -s -O "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xf "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm -f "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  export PATH="$PWD/flutter/bin:$PATH"
fi

flutter --version

cd apk

# Write apk/.env with the default connection string if not present
if [ ! -f .env ] || [ ! -s .env ]; then
  CONN="${NEON_CONNECTION_STRING:-postgresql://neondb_owner:npg_OtyTj7F9Aqnz@ep-red-sea-b5yphk96-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require}"
  printf 'NEON_CONNECTION_STRING="%s"\n' "$CONN" > .env
  echo 'NEON_REGION_ENDPOINT="https://ep-red-sea-b5yphk96.c-7.us-east-2.aws.neon.tech/sql"' >> .env
  echo 'NEON_DIRECT_ENDPOINT="https://ep-red-sea-b5yphk96.c-7.us-east-2.aws.neon.tech/sql"' >> .env
fi

flutter pub get
flutter build web --release

# Ensure vercel.json is in build/web
if [ -f web/vercel.json ]; then
  cp web/vercel.json build/web/vercel.json
fi

echo "=== Flutter Web Build Complete ==="

