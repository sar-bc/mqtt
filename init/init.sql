-- init/init.sql (фрагмент)

-- Таблица users остается, но поле password_hash теперь будет содержать PBKDF2-хеш
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,  -- Формат: PBKDF2$sha256$901$...
    is_superuser SMALLINT DEFAULT 0
);

-- Таблица acls остается без изменений
CREATE TABLE IF NOT EXISTS acls (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    rw INTEGER NOT NULL CHECK (rw IN (1, 2, 3))
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
CREATE INDEX IF NOT EXISTS idx_acls_username ON acls (username);

-- !!! ВНИМАНИЕ: Тестового пользователя нужно добавить с правильным хешем PBKDF2.
-- Временно удалите или закомментируйте вставку с bcrypt-хешем.
-- Правильный хеш можно сгенерировать позже через утилиту np или адаптированный Python-скрипт.
-- INSERT INTO users (username, password_hash, is_superuser) VALUES ('test', '...', 0);