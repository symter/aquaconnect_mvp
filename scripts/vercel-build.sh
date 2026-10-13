#!/usr/bin/env bash
set -euo pipefail

if [ -z "${API_BASE_URL:-}" ]; then
  echo "Error: API_BASE_URL is not set. Add it under Vercel Project Settings > Environment Variables (e.g. https://your-service.up.railway.app)." >&2
  exit 1
fi

git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
_flutter/bin/flutter config --enable-web
_flutter/bin/flutter pub get
_flutter/bin/flutter build web --release --dart-define=USE_MOCK=false --dart-define=API_BASE_URL="$API_BASE_URL"

# flutter build web skips dot-folders, so copy the Android TWA's Digital
# Asset Links file (proves the app owns this domain) in by hand.
mkdir -p build/web/.well-known
cp web/.well-known/assetlinks.json build/web/.well-known/assetlinks.json
