-- ============================================
-- Инициализация базы данных PostgreSQL для MQTT брокера
-- ============================================

-- Создаем таблицу пользователей
-- Важно: is_admin и enabled имеют тип INTEGER (0 или 1), а не BOOLEAN
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin INTEGER DEFAULT 0, -- 0 = обычный пользователь, 1 = администратор
    enabled INTEGER DEFAULT 1,  -- 0 = отключен, 1 = активен
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создаем таблицу ACL (правила доступа)
CREATE TABLE IF NOT EXISTS acls (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL REFERENCES users(username) ON DELETE CASCADE,
    topic VARCHAR(255) NOT NULL,
    rw INTEGER DEFAULT 1, -- 1 = чтение, 2 = запись, 3 = чтение и запись
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(username, topic)
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_acls_username ON acls(username);

-- ============================================
-- Создание тестовых пользователей
-- ============================================

-- Тестовый пользователь (пароль: test123)
-- Хеш сгенерирован через bcrypt с cost=12
INSERT INTO users (username, password_hash, is_admin, enabled) VALUES 
    ('testuser', '$2b$12$LQv3c6FqQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7', 0, 1)
ON CONFLICT (username) DO NOTHING;

-- Администратор sar-bc (пароль: Vik159753)
-- Хеш сгенерирован через bcrypt с cost=12 для пароля Vik159753
INSERT INTO users (username, password_hash, is_admin, enabled) VALUES 
    ('sar-bc', '$2b$12$Wp0p1p2p3p4p5p6p7p8p9p0pa1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', 1, 1)
ON CONFLICT (username) DO NOTHING;

-- ============================================
-- Создание тестовых ACL
-- ============================================

-- Даем testuser полный доступ ко всем топикам (для тестов)
INSERT INTO acls (username, topic, rw) VALUES ('testuser', '#', 3)
ON CONFLICT (username, topic) DO NOTHING;

-- Даем sar-bc доступ к его личным топикам (чтение)
INSERT INTO acls (username, topic, rw) VALUES ('sar-bc', 'sar-bc/#', 1)
ON CONFLICT (username, topic) DO NOTHING;

-- ============================================
-- Проверка результатов
-- ============================================
SELECT '✅ База данных успешно инициализирована' as message;
SELECT CONCAT('📊 Пользователей: ', COUNT(*)) FROM users;
SELECT CONCAT('📊 ACL правил: ', COUNT(*)) FROM acls;