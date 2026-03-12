# Dockerfile
FROM eclipse-mosquitto:2.0.18 AS builder

# Устанавливаем зависимости для компиляции
RUN apk add --no-cache \
    git \
    build-base \
    mosquitto-dev \
    openssl-dev \
    postgresql-dev \
    linux-headers

# Клонируем плагин
WORKDIR /tmp
RUN git clone https://github.com/jpmens/mosquitto-auth-plug.git

# Компилируем плагин (жестко отключаем MySQL)
WORKDIR /tmp/mosquitto-auth-plug
RUN cp config.mk.in config.mk && \
    # Включаем PostgreSQL
    sed -i 's/^#\(BE_POSTGRES ?= yes\)/\1/' config.mk && \
    # Жестко отключаем MySQL (заменяем всю строку на закомментированную)
    sed -i 's/^BE_MYSQL ?= yes/#BE_MYSQL ?= no/' config.mk && \
    # Отключаем всё остальное
    sed -i 's/^BE_SQLITE ?= yes/#BE_SQLITE ?= no/' config.mk && \
    sed -i 's/^BE_REDIS ?= yes/#BE_REDIS ?= no/' config.mk && \
    sed -i 's/^BE_LDAP ?= yes/#BE_LDAP ?= no/' config.mk && \
    sed -i 's/^BE_HTTP ?= yes/#BE_HTTP ?= no/' config.mk && \
    sed -i 's/^BE_JWT ?= yes/#BE_JWT ?= no/' config.mk && \
    sed -i 's/^BE_MONGO ?= yes/#BE_MONGO ?= no/' config.mk && \
    # Проверяем результат (опционально)
    grep "BE_" config.mk && \
    # Чистим перед сборкой
    make clean && \
    # Компилируем
    make

# Финальный образ
FROM eclipse-mosquitto:2.0.18
COPY --from=builder /tmp/mosquitto-auth-plug/auth-plug.so /mosquitto/
COPY config/mosquitto.conf /mosquitto/config/
