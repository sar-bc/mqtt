# Dockerfile
FROM eclipse-mosquitto:2.0.18 AS builder

# Устанавливаем зависимости для компиляции (Alpine Linux использует apk)
RUN apk add --no-cache \
    git \
    build-base \
    mosquitto-dev \
    openssl-dev \
    postgresql-dev \
    linux-headers

# Клонируем и компилируем плагин
WORKDIR /tmp
RUN git clone https://github.com/jpmens/mosquitto-auth-plug.git
WORKDIR /tmp/mosquitto-auth-plug
RUN cp config.mk.in config.mk && \
    sed -i 's/#BE_POSTGRES ?= yes/BE_POSTGRES ?= yes/' config.mk && \
    sed -i 's/BE_MYSQL ?= yes/#BE_MYSQL ?= no/' config.mk && \
    sed -i 's/BE_SQLITE ?= yes/#BE_SQLITE ?= no/' config.mk && \
    make

# Финальный образ
FROM eclipse-mosquitto:2.0.18
COPY --from=builder /tmp/mosquitto-auth-plug/auth-plug.so /mosquitto/
COPY config/mosquitto.conf /mosquitto/config/