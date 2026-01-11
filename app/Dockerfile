# Production Flutter Web Dockerfile
FROM ubuntu:22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/usr/local/flutter
ENV FLUTTER_VERSION=3.24.5
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter precache --web \
    && flutter config --enable-web

WORKDIR /app

COPY pubspec.* ./
RUN flutter pub get

COPY . .

RUN flutter build web --release

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
