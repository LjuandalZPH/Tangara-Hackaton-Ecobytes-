#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="${HOME}/flutter"

if [[ ! -x "${FLUTTER_DIR}/bin/flutter" ]]; then
  git clone --branch stable --depth 1 https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --enable-web
flutter pub get
flutter build web --release --base-href "/"