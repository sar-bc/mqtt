# MQTT Broker with PostgreSQL Authentication

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![Mosquitto](https://img.shields.io/badge/mosquitto-2.0-green.svg)](https://mosquitto.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-15-blue.svg)](https://www.postgresql.org/)

Этот проект разворачивает **полноценный MQTT-брокер** (на базе Eclipse Mosquitto) с **аутентификацией и авторизацией (ACL) через PostgreSQL**. Брокер работает в Docker-контейнерах, управляется через `docker-compose` и включает удобные скрипты для менеджмента пользователей и прав доступа.

## ✨ Возможности

* ✅ **Полноценный MQTT-брокер** на базе Mosquitto 2.0 с поддержкой MQTT v3.1.1 и v5.0.
* ✅ **Аутентификация и авторизация (ACL)** через внешнюю базу данных PostgreSQL.
* ✅ **Гибкое управление пользователями** и их правами на топики (чтение/запись).
* ✅ **Два скрипта для управления:**
  * `manage_users_postgres.py` — продвинутый Python-скрипт с поддержкой аргументов командной строки.
  * `manage_users_postgres.sh` — простой интерактивный Bash-скрипт с меню.
* ✅ **Полная контейнеризация:** брокер и база данных запускаются в отдельных контейнерах, связанных общей сетью.
* ✅ **Автоматическая инициализация базы данных** при первом запуске (структура таблиц, тестовый пользователь).
* ✅ **Персистентность данных:** папки `data/` и `postgres_data/` хранят данные брокера и БД между перезапусками.

## 🛠️ Технологии

* **Брокер:** [Eclipse Mosquitto](https://mosquitto.org/) + [mosquitto-go-auth](https://github.com/iegomez/mosquitto-go-auth) (плагин аутентификации)
* **База данных:** PostgreSQL 15
* **Оркестрация:** Docker, Docker Compose V2
* **Управление:** Python 3 + `bcrypt`/`psycopg2-binary`, Bash

## 🚀 Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/sar-bc/mqtt.git
cd mqtt
```

### 2. Настройка и запуск контейнеров

Проект полностью готов к запуску. Вам не нужно ничего менять для теста.

```bash
# Запустить контейнеры в фоновом режиме
docker compose up -d

# Проверить, что все контейнеры запустились
docker compose ps
```

После первого запуска база данных будет автоматически инициализирована скриптом из папки `init/`.

### 3. Настройка виртуального окружения Python (рекомендуется)

Для работы Python-скрипта управления пользователями необходимо установить зависимости в изолированном окружении.

```bash
# Установить пакет для создания виртуальных окружений (если не установлен)
sudo apt install python3-venv python3-full -y

# Создать виртуальное окружение в папке проекта
python3 -m venv venv

# Активировать его
source venv/bin/activate

# Установить зависимости
pip install --upgrade pip
pip install bcrypt psycopg2-binary

# Теперь можно работать. Для выхода из окружения используйте команду: deactivate
```

### 4. Управление пользователями и ACL

Для управления используйте Python-скрипт (из виртуального окружения) или Bash-скрипт (не требует Python-зависимостей, но нужен клиент `psql`).

#### Вариант А: Python-скрипт (рекомендуется)

```bash
# Убедитесь, что виртуальное окружение активировано (см. шаг 3)
source venv/bin/activate

# Показать справку по командам
python manage_users_postgres.py -h

# Создать обычного пользователя
python manage_users_postgres.py add -u sensor_reader

# Создать администратора
python manage_users_postgres.py add -u admin -a

# Посмотреть список пользователей
python manage_users_postgres.py list

# Добавить правило доступа (ACL): пользователь sensor_reader может читать топики sensors/#
python manage_users_postgres.py add-acl -u sensor_reader -t "sensors/#" -r 1

# Посмотреть все ACL
python manage_users_postgres.py list-acls

# Посмотреть ACL конкретного пользователя
python manage_users_postgres.py list-acls -u sensor_reader

# Для выхода из виртуального окружения
deactivate
```

**Параметры прав доступа (`-r`, `--rw`):**

* `1` — только чтение (read)
* `2` — только запись (write)
* `3` — чтение и запись (readwrite)

#### Вариант Б: Интерактивный Bash-скрипт

Этот скрипт не требует виртуального окружения, но для работы ему нужен клиент PostgreSQL (`psql`), установленный на хосте.

```bash
# Установить PostgreSQL клиент (если не установлен)
sudo apt update && sudo apt install postgresql-client -y

# Сделать скрипт исполняемым (один раз)
chmod +x manage_users_postgres.sh

# Запустить скрипт
./manage_users_postgres.sh
```

Следуйте инструкциям в интерактивном меню.

### 5. Тестирование подключения

Установите MQTT-клиент на любом сервере, откуда планируете подключаться.

```bash
# На Ubuntu/Debian
sudo apt install mosquitto-clients -y
```

**Тест 1: Локально на сервере с брокером**

```bash
# В первом терминале подписываемся на все топики
mosquitto_sub -h localhost -t "#" -u sensor_reader -P ваш_пароль -v

# Во втором терминале отправляем сообщение
mosquitto_pub -h localhost -t "sensors/temperature" -m "22.5" -u sensor_reader -P ваш_пароль
```

**Тест 2: Удаленно с клиентской машины**

```bash
# Замените mqtt.example.com на ваш домен или IP-адрес сервера
mosquitto_sub -h mqtt.example.com -t "sensors/#" -u sensor_reader -P ваш_пароль -v
```

## 📁 Структура проекта

```
mqtt/
├── .gitignore                 # Файлы и папки, исключенные из Git
├── README.md                  # Этот файл
├── docker-compose.yml         # Оркестрация контейнеров
├── manage_users_postgres.py   # Python-скрипт управления
├── manage_users_postgres.sh   # Bash-скрипт управления (интерактивный)
├── requirements.txt           # Зависимости Python
├── config/
│   └── mosquitto.conf         # Конфигурация Mosquitto с плагином go-auth
├── init/
│   └── init.sql               # SQL-скрипт для инициализации базы данных
└── venv/                      # Виртуальное окружение Python (создается локально)
```

## ⚙️ Конфигурация

### Основные настройки (`docker-compose.yml`)

Вы можете изменить пароли и имена пользователей для PostgreSQL, отредактировав переменные окружения в файле `docker-compose.yml`:

* `POSTGRES_PASSWORD`
* `POSTGRES_USER`
* `POSTGRES_DB`

**Не забудьте также изменить их в `config/mosquitto.conf` и в скриптах управления.**

### Настройки брокера (`config/mosquitto.conf`)

Файл содержит все основные параметры Mosquitto и плагина. Ключевые моменты:

* `listener 1883 0.0.0.0` — разрешает подключения с любых сетевых интерфейсов.
* `auth_plugin /mosquitto/go-auth.so` — загружает плагин аутентификации.
* `auth_opt_backends postgres` — указывает использовать PostgreSQL.
* `auth_opt_pg_*` — параметры подключения к базе данных.
* `auth_opt_hasher bcrypt` — явно указывает использовать bcrypt для хеширования паролей.

## 🐳 Работа с Docker

Основные команды для управления проектом:

```bash
# Запустить все контейнеры
docker compose up -d

# Остановить все контейнеры
docker compose down

# Остановить контейнеры и удалить тома (база данных будет очищена!)
docker compose down -v

# Посмотреть логи всех контейнеров
docker compose logs -f

# Посмотреть логи конкретного контейнера
docker logs mqtt_cont -f
docker logs mqtt_postgres -f

# Пересобрать образы (если вносились изменения в Dockerfile)
docker compose build --no-cache
```

## 🔧 Устранение неполадок

1. **Ошибка `Connection refused` при подключении:**

   * Убедитесь, что контейнеры запущены: `docker compose ps`.
   * Проверьте, слушает ли брокер порт: `docker port mqtt_cont`.
   * Проверьте настройки файрвола на сервере: `sudo ufw status` (порт 1883 должен быть открыт).
   * Для облачных серверов (AWS, DigitalOcean и др.) проверьте правила файрвола (Security Group/Firewall) в панели управления хостинга.
2. **Ошибка `not authorised`:**

   * Проверьте, что пользователь существует: `python manage_users_postgres.py list`.
   * Проверьте, что у пользователя есть ACL на нужный топик: `python manage_users_postgres.py list-acls -u имя_пользователя`.
   * Убедитесь, что в логах контейнера `mqtt_cont` нет ошибок при загрузке плагина.
   * Попробуйте пересоздать пароль пользователя: `python manage_users_postgres.py passwd -u имя_пользователя`.
3. **Ошибки Python (модуль не найден):**

   * Убедитесь, что вы активировали виртуальное окружение (`source venv/bin/activate`).
   * Установите зависимости: `pip install -r requirements.txt`.

## 🤝 Вклад в проект

Предложения по улучшению и Pull Request'ы приветствуются.

## 📄 Лицензия

MIT

# MQTT Broker with PostgreSQL Authentication

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![Mosquitto](https://img.shields.io/badge/mosquitto-2.0-green.svg)](https://mosquitto.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-15-blue.svg)](https://www.postgresql.org/)

Этот проект разворачивает **полноценный MQTT-брокер** (на базе Eclipse Mosquitto) с **аутентификацией и авторизацией (ACL) через PostgreSQL**. Брокер работает в Docker-контейнерах, управляется через `docker-compose` и включает удобные скрипты для менеджмента пользователей и прав доступа.

## ✨ Возможности

* ✅ **Полноценный MQTT-брокер** на базе Mosquitto 2.0 с поддержкой MQTT v3.1.1 и v5.0.
* ✅ **Аутентификация и авторизация (ACL)** через внешнюю базу данных PostgreSQL.
* ✅ **Гибкое управление пользователями** и их правами на топики (чтение/запись).
* ✅ **Два скрипта для управления:**
  * `manage_users_postgres.py` — продвинутый Python-скрипт с поддержкой аргументов командной строки.
  * `manage_users_postgres.sh` — простой интерактивный Bash-скрипт с меню.
* ✅ **Полная контейнеризация:** брокер и база данных запускаются в отдельных контейнерах, связанных общей сетью.
* ✅ **Автоматическая инициализация базы данных** при первом запуске (структура таблиц, тестовый пользователь).
* ✅ **Персистентность данных:** папки `data/` и `postgres_data/` хранят данные брокера и БД между перезапусками.

## 🛠️ Технологии

* **Брокер:** [Eclipse Mosquitto](https://mosquitto.org/) + [mosquitto-go-auth](https://github.com/iegomez/mosquitto-go-auth) (плагин аутентификации)
* **База данных:** PostgreSQL 15
* **Оркестрация:** Docker, Docker Compose V2
* **Управление:** Python 3 + `bcrypt`/`psycopg2-binary`, Bash

## 🚀 Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/sar-bc/mqtt.git
cd mqtt
```

### 2. Настройка и запуск контейнеров

Проект полностью готов к запуску. Вам не нужно ничего менять для теста.

```bash
# Запустить контейнеры в фоновом режиме
docker compose up -d

# Проверить, что все контейнеры запустились
docker compose ps
```

После первого запуска база данных будет автоматически инициализирована скриптом из папки `init/`.

### 3. Настройка виртуального окружения Python (рекомендуется)

Для работы Python-скрипта управления пользователями необходимо установить зависимости в изолированном окружении.

```bash
# Установить пакет для создания виртуальных окружений (если не установлен)
sudo apt install python3-venv python3-full -y

# Создать виртуальное окружение в папке проекта
python3 -m venv venv

# Активировать его
source venv/bin/activate

# Установить зависимости
pip install --upgrade pip
pip install bcrypt psycopg2-binary

# Теперь можно работать. Для выхода из окружения используйте команду: deactivate
```

### 4. Управление пользователями и ACL

Для управления используйте Python-скрипт (из виртуального окружения) или Bash-скрипт (не требует Python-зависимостей, но нужен клиент `psql`).

#### Вариант А: Python-скрипт (рекомендуется)

```bash
# Убедитесь, что виртуальное окружение активировано (см. шаг 3)
source venv/bin/activate

# Показать справку по командам
python manage_users_postgres.py -h

# Создать обычного пользователя
python manage_users_postgres.py add -u sensor_reader

# Создать администратора
python manage_users_postgres.py add -u admin -a

# Посмотреть список пользователей
python manage_users_postgres.py list

# Добавить правило доступа (ACL): пользователь sensor_reader может читать топики sensors/#
python manage_users_postgres.py add-acl -u sensor_reader -t "sensors/#" -r 1

# Посмотреть все ACL
python manage_users_postgres.py list-acls

# Посмотреть ACL конкретного пользователя
python manage_users_postgres.py list-acls -u sensor_reader

# Для выхода из виртуального окружения
deactivate
```

**Параметры прав доступа (`-r`, `--rw`):**

* `1` — только чтение (read)
* `2` — только запись (write)
* `3` — чтение и запись (readwrite)

#### Вариант Б: Интерактивный Bash-скрипт

Этот скрипт не требует виртуального окружения, но для работы ему нужен клиент PostgreSQL (`psql`), установленный на хосте.

```bash
# Установить PostgreSQL клиент (если не установлен)
sudo apt update && sudo apt install postgresql-client -y

# Сделать скрипт исполняемым (один раз)
chmod +x manage_users_postgres.sh

# Запустить скрипт
./manage_users_postgres.sh
```

Следуйте инструкциям в интерактивном меню.

### 5. Тестирование подключения

Установите MQTT-клиент на любом сервере, откуда планируете подключаться.

```bash
# На Ubuntu/Debian
sudo apt install mosquitto-clients -y
```

**Тест 1: Локально на сервере с брокером**

```bash
# В первом терминале подписываемся на все топики
mosquitto_sub -h localhost -t "#" -u sensor_reader -P ваш_пароль -v

# Во втором терминале отправляем сообщение
mosquitto_pub -h localhost -t "sensors/temperature" -m "22.5" -u sensor_reader -P ваш_пароль
```

**Тест 2: Удаленно с клиентской машины**

```bash
# Замените mqtt.example.com на ваш домен или IP-адрес сервера
mosquitto_sub -h mqtt.example.com -t "sensors/#" -u sensor_reader -P ваш_пароль -v
```

## 📁 Структура проекта

```
mqtt/
├── .gitignore                 # Файлы и папки, исключенные из Git
├── README.md                  # Этот файл
├── docker-compose.yml         # Оркестрация контейнеров
├── manage_users_postgres.py   # Python-скрипт управления
├── manage_users_postgres.sh   # Bash-скрипт управления (интерактивный)
├── requirements.txt           # Зависимости Python
├── config/
│   └── mosquitto.conf         # Конфигурация Mosquitto с плагином go-auth
├── init/
│   └── init.sql               # SQL-скрипт для инициализации базы данных
└── venv/                      # Виртуальное окружение Python (создается локально)
```

## ⚙️ Конфигурация

### Основные настройки (`docker-compose.yml`)

Вы можете изменить пароли и имена пользователей для PostgreSQL, отредактировав переменные окружения в файле `docker-compose.yml`:

* `POSTGRES_PASSWORD`
* `POSTGRES_USER`
* `POSTGRES_DB`

**Не забудьте также изменить их в `config/mosquitto.conf` и в скриптах управления.**

### Настройки брокера (`config/mosquitto.conf`)

Файл содержит все основные параметры Mosquitto и плагина. Ключевые моменты:

* `listener 1883 0.0.0.0` — разрешает подключения с любых сетевых интерфейсов.
* `auth_plugin /mosquitto/go-auth.so` — загружает плагин аутентификации.
* `auth_opt_backends postgres` — указывает использовать PostgreSQL.
* `auth_opt_pg_*` — параметры подключения к базе данных.
* `auth_opt_hasher bcrypt` — явно указывает использовать bcrypt для хеширования паролей.

## 🐳 Работа с Docker

Основные команды для управления проектом:

```bash
# Запустить все контейнеры
docker compose up -d

# Остановить все контейнеры
docker compose down

# Остановить контейнеры и удалить тома (база данных будет очищена!)
docker compose down -v

# Посмотреть логи всех контейнеров
docker compose logs -f

# Посмотреть логи конкретного контейнера
docker logs mqtt_cont -f
docker logs mqtt_postgres -f

# Пересобрать образы (если вносились изменения в Dockerfile)
docker compose build --no-cache
```

## 🔧 Устранение неполадок

1. **Ошибка `Connection refused` при подключении:**

   * Убедитесь, что контейнеры запущены: `docker compose ps`.
   * Проверьте, слушает ли брокер порт: `docker port mqtt_cont`.
   * Проверьте настройки файрвола на сервере: `sudo ufw status` (порт 1883 должен быть открыт).
   * Для облачных серверов (AWS, DigitalOcean и др.) проверьте правила файрвола (Security Group/Firewall) в панели управления хостинга.
2. **Ошибка `not authorised`:**

   * Проверьте, что пользователь существует: `python manage_users_postgres.py list`.
   * Проверьте, что у пользователя есть ACL на нужный топик: `python manage_users_postgres.py list-acls -u имя_пользователя`.
   * Убедитесь, что в логах контейнера `mqtt_cont` нет ошибок при загрузке плагина.
   * Попробуйте пересоздать пароль пользователя: `python manage_users_postgres.py passwd -u имя_пользователя`.
3. **Ошибки Python (модуль не найден):**

   * Убедитесь, что вы активировали виртуальное окружение (`source venv/bin/activate`).
   * Установите зависимости: `pip install -r requirements.txt`.

## 🤝 Вклад в проект

Предложения по улучшению и Pull Request'ы приветствуются.

## 📄 Лицензия

MIT
