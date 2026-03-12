-- Создание таблицы пользователей
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,  -- Формат: PBKDF2$sha256$901$...
    is_superuser SMALLINT DEFAULT 0
);

-- Создание таблицы ACL
CREATE TABLE IF NOT EXISTS acls (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    rw INTEGER NOT NULL CHECK (rw IN (1, 2, 3))  -- 1=read, 2=write, 3=readwrite
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
CREATE INDEX IF NOT EXISTS idx_acls_username ON acls (username);

-- ⚠️ ВНИМАНИЕ: Тестовый пользователь НЕ ДОБАВЛЯЕТСЯ!
-- Его нужно создать через обновленный Python-скрипт, который генерирует PBKDF2-хеши.
