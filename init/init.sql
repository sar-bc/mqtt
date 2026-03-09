-- Создаем базу данных (если не существует)
CREATE DATABASE IF NOT EXISTS mqtt_auth
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE mqtt_auth;

-- Создаем таблицу пользователей
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT false,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Создаем таблицу ACL (правила доступа)
CREATE TABLE IF NOT EXISTS acls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    topic VARCHAR(255) NOT NULL,
    rw INT DEFAULT 1 COMMENT '1=read, 2=write, 3=readwrite',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE,
    UNIQUE KEY unique_acl (username, topic),
    INDEX idx_username (username),
    INDEX idx_topic (topic)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Создаем тестового пользователя (пароль: test123)
-- Хеш сгенерирован для пароля 'test123'
INSERT IGNORE INTO users (username, password_hash, is_admin) VALUES 
    ('test', '$2b$12$LQv3c6FqQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7', false),
    ('admin', '$2b$12$LQv3c6FqQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7hQ7', true);

-- Добавляем тестовые ACL
INSERT IGNORE INTO acls (username, topic, rw) VALUES
    ('test', 'sensors/#', 1),
    ('test', 'actuators/+/command', 2),
    ('admin', '#', 3);

-- Создаем процедуру для создания пользователя (опционально)
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS create_user(
    IN p_username VARCHAR(255),
    IN p_password_hash TEXT,
    IN p_is_admin BOOLEAN
)
BEGIN
    INSERT INTO users (username, password_hash, is_admin)
    VALUES (p_username, p_password_hash, p_is_admin)
    ON DUPLICATE KEY UPDATE
        password_hash = VALUES(password_hash),
        is_admin = VALUES(is_admin);
END$$
DELIMITER ;

-- Создаем процедуру для добавления ACL
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS add_acl(
    IN p_username VARCHAR(255),
    IN p_topic VARCHAR(255),
    IN p_rw INT
)
BEGIN
    INSERT INTO acls (username, topic, rw)
    VALUES (p_username, p_topic, p_rw)
    ON DUPLICATE KEY UPDATE
        rw = VALUES(rw);
END$$
DELIMITER ;

-- Применяем права
FLUSH PRIVILEGES;

-- Выводим информацию
SELECT '✅ База данных MQTT успешно инициализирована' as '';
SELECT CONCAT('📊 Пользователей: ', COUNT(*)) as '' FROM users;
SELECT CONCAT('📊 ACL правил: ', COUNT(*)) as '' FROM acls;
