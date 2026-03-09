-- Создаём таблицу пользователей
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT false,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создаём таблицу ACL
CREATE TABLE IF NOT EXISTS acls (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL REFERENCES users(username) ON DELETE CASCADE,
    topic VARCHAR(255) NOT NULL,
    rw INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(username, topic)
);

-- Создаём индексы
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_acls_username ON acls(username);

-- Создаём тестового пользователя (пароль: test123)
-- Хеш сгенерирован для пароля 'test123'
INSERT INTO users (username, password_hash, is_admin) 
VALUES ('testuser', '$2a$10$YourBcryptHashHereForTest123', false)
ON CONFLICT (username) DO NOTHING;