# ── Stage 1: build ──
# Las imágenes de Flutter de terceros (cirruslabs, instrumentisto) suelen ir
# varias versiones detrás del release estable oficial, así que instalamos el
# SDK directo desde el archivo de Google, pineado a la misma versión que usa
# el equipo en local (`flutter --version`) — evita mismatches de Dart SDK
# contra el `environment.sdk` de pubspec.yaml.
FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git xz-utils \
    && rm -rf /var/lib/apt/lists/*

ARG FLUTTER_VERSION=3.44.7
RUN curl -fSL --retry 5 --retry-delay 5 --retry-all-errors \
    -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz
ENV PATH="/opt/flutter/bin:${PATH}"
RUN git config --global --add safe.directory /opt/flutter

WORKDIR /app
COPY . .

# URL del backend, configurable en build (ver lib/core/config/api_config.dart)
ARG API_BASE_URL=http://localhost:8000

RUN flutter config --no-analytics
RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ── Stage 2: serve ──
# nginx sirve el build estático — no requiere el SDK de Flutter en runtime
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
