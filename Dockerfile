# Stage 1: Build
FROM debian:bookworm-slim AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils libglu1-mesa python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Jalankan flutter doctor untuk inisialisasi
RUN flutter doctor

# Set working directory
WORKDIR /app

# Copy files
COPY . .

# OPENAI_API_KEY di-pass dari Coolify build args
ARG OPENAI_API_KEY=""

# Ambil dependencies dan build web
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release --base-href / --pwa-strategy=none \
    --dart-define=OPENAI_API_KEY=${OPENAI_API_KEY}

# Stage 2: Runtime (Serving with Nginx)
FROM nginx:stable-alpine

# Copy hasil build ke folder nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# SPA routing: semua path fallback ke index.html
RUN printf 'server {\n  listen 80;\n  root /usr/share/nginx/html;\n  index index.html;\n  location / {\n    try_files $uri $uri/ /index.html;\n  }\n}\n' \
    > /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
