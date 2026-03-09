-- Создаем таблицу пользователей
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT false,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создаем таблицу ACL (прав доступа)
CREATE TABLE IF NOT EXISTS acls (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL REFERENCES users(username) ON DELETE CASCADE,
    topic VARCHAR(255) NOT NULL,
    rw INTEGER DEFAULT 1,  -- 1=read, 2=write, 3=readwrite
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(username, topic)
);

-- Создаем индексы
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_enabled ON users(enabled);
CREATE INDEX idx_acls_username ON acls(username);
CREATE INDEX idx_acls_topic ON acls(topic);

-- Создаем функцию для обновления last_modified
CREATE OR REPLACE FUNCTION update_last_modified()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создаем триггер для автоматического обновления last_modified
CREATE TRIGGER update_users_modtime
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_last_modified();

-- Комментарии для документации
COMMENT ON TABLE users IS 'MQTT users for authentication';
COMMENT ON TABLE acls IS 'Access Control List for MQTT topics';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash of password';
COMMENT ON COLUMN acls.rw IS '1=read, 2=write, 3=readwrite';
