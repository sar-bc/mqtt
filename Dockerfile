# Dockerfile
FROM eclipse-mosquitto:2.0.18 AS builder

# Устанавливаем зависимости для компиляции (Alpine Linux)
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

# Правильно настраиваем config.mk - отключаем MySQL и SQLite, включаем PostgreSQL
RUN cp config.mk.in config.mk && \
    # Включаем PostgreSQL
    sed -i 's/^#\(BE_POSTGRES ?= yes\)/\1/' config.mk && \
    # Отключаем MySQL (заменяем 'yes' на 'no')
    sed -i 's/^\(BE_MYSQL ?= \)yes/\1no/' config.mk && \
    # Отключаем SQLite
    sed -i 's/^\(BE_SQLITE ?= \)yes/\1no/' config.mk && \
    # Убеждаемся, что другие бэкенды отключены
    sed -i 's/^\(BE_REDIS ?= \)yes/\1no/' config.mk && \
    sed -i 's/^\(BE_LDAP ?= \)yes/\1no/' config.mk && \
    sed -i 's/^\(BE_HTTP ?= \)yes/\1no/' config.mk && \
    sed -i 's/^\(BE_JWT ?= \)yes/\1no/' config.mk && \
    sed -i 's/^\(BE_MONGO ?= \)yes/\1no/' config.mk && \
    # Проверяем результат
    cat config.mk | grep "BE_"

# Компилируем
RUN make

# Финальный образ
FROM eclipse-mosquitto:2.0.18
COPY --from=builder /tmp/mosquitto-auth-plug/auth-plug.so /mosquitto/
COPY config/mosquitto.conf /mosquitto/config/