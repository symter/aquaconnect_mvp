#!/usr/bin/env bash
set -euo pipefail

git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
_flutter/bin/flutter config --enable-web
_flutter/bin/flutter pub get
_flutter/bin/flutter build web --release --dart-define=USE_MOCK=false --dart-define=API_BASE_URL="$API_BASE_URL"
