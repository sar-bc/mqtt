# Этап 1: Сборка Go-плагина
FROM golang:1.22-alpine AS builder

# Устанавливаем зависимости для сборки
RUN apk add --no-cache \
    git \
    gcc \
    musl-dev \
    mosquitto-dev \
    openssl-dev \
    sqlite-dev

# Клонируем актуальный форк Go-плагина
WORKDIR /src
RUN git clone https://github.com/iegomez/mosquitto-go-auth.git .

# Собираем плагин
ENV CGO_CFLAGS="-I/usr/include -fPIC"
ENV CGO_LDFLAGS="-shared"
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
