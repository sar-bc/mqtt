# Dockerfile
FROM eclipse-mosquitto:2.0.18 AS builder

# Устанавливаем зависимости для компиляции
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    libmosquitto-dev \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

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