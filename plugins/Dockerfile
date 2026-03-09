# Этап 1: Сборка Go-плагина
FROM golang:1.24-alpine AS builder

# Устанавливаем зависимости для сборки (убрали sqlite-dev)
RUN apk add --no-cache \
    git \
    gcc \
    musl-dev \
    mosquitto-dev \
    openssl-dev \
    postgresql-dev \
    make

# Важно: отключаем SQLite через тег сборки
ENV CGO_CFLAGS="-I/usr/include -fPIC"
ENV CGO_LDFLAGS="-shared"
ENV GOFLAGS="-tags=sqlite_omit_load_extension"

# Клонируем форк Go-плагина
WORKDIR /src
RUN git clone https://github.com/iegomez/mosquitto-go-auth.git .

# Переходим в директорию и собираем
WORKDIR /src
RUN make

# Этап 2: Финальный образ
FROM eclipse-mosquitto:2.0

# Устанавливаем клиент PostgreSQL (для проверки соединения)
RUN apk add --no-cache postgresql-client

# Копируем собранный плагин
COPY --from=builder /src/go-auth.so /mosquitto/plugins/

# Создаем необходимые директории
RUN mkdir -p /mosquitto/data /mosquitto/log /mosquitto/config

# Права доступа
RUN chown -R mosquitto:mosquitto /mosquitto
