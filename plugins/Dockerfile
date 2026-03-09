# Этап 1: Сборка Go-плагина
FROM golang:1.24-alpine AS builder

# Устанавливаем зависимости для сборки
RUN apk add --no-cache \
    git \
    gcc \
    musl-dev \
    mosquitto-dev \
    openssl-dev \
    sqlite-dev \
    make

# Добавляем необходимые флаги для 64-битной сборки
ENV CGO_CFLAGS="-I/usr/include -fPIC -D_LARGEFILE64_SOURCE"
ENV CGO_LDFLAGS="-shared"
ENV GOARCH=amd64

# Клонируем актуальный форк Go-плагина
WORKDIR /src
RUN git clone https://github.com/iegomez/mosquitto-go-auth.git .

# Собираем плагин
RUN make

# Этап 2: Финальный образ
FROM eclipse-mosquitto:2.0

# Устанавливаем SQLite и зависимости
RUN apk add --no-cache sqlite libcrypto3 libssl3

# Копируем собранный плагин
COPY --from=builder /src/go-auth.so /mosquitto/plugins/

# Создаем необходимые директории
RUN mkdir -p /mosquitto/data /mosquitto/log /mosquitto/config

# Права доступа
RUN chown -R mosquitto:mosquitto /mosquitto
