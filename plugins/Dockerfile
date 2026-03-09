# Этап 1: Сборка плагина
FROM eclipse-mosquitto:2.0 AS builder

# Устанавливаем зависимости для сборки
RUN apk add --no-cache \
    git \
    make \
    gcc \
    musl-dev \
    openssl-dev \
    sqlite-dev \
    mosquitto-dev \
    linux-headers

# Клонируем репозиторий плагина
WORKDIR /tmp
RUN git clone https://github.com/jpmens/mosquitto-auth-plug.git

# Настраиваем конфиг для сборки
WORKDIR /tmp/mosquitto-auth-plug
RUN cp config.mk.in config.mk && \
    sed -i \
        -e 's/BACKEND_SQLITE ?= no/BACKEND_SQLITE ?= yes/' \
        -e 's/BACKEND_MYSQL ?= yes/BACKEND_MYSQL ?= no/' \
        -e 's/BACKEND_REDIS ?= yes/BACKEND_REDIS ?= no/' \
        -e 's#OPENSSLDIR = /usr/lib/ssl#OPENSSLDIR = /etc/ssl#' \
        config.mk

# Собираем плагин
RUN make

# Этап 2: Финальный образ
FROM eclipse-mosquitto:2.0

# Копируем собранный плагин и утилиту np
COPY --from=builder /tmp/mosquitto-auth-plug/auth-plug.so /mosquitto/plugins/
COPY --from=builder /tmp/mosquitto-auth-plug/np /mosquitto/plugins/

# Устанавливаем sqlite3 для работы с БД
RUN apk add --no-cache sqlite

# Создаем необходимые директории
RUN mkdir -p /mosquitto/plugins /mosquitto/data /mosquitto/log /mosquitto/config

# Создаем пользователя mosquitto если нужно (в 2.0 он уже есть)
# Проверяем и исправляем права
RUN chown -R mosquitto:mosquitto /mosquitto || true