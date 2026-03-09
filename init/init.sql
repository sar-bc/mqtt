-- Создаем базу данных
CREATE DATABASE IF NOT EXISTS mqtt_auth
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE mqtt_auth;

-- Создаем пользователя с правильным методом аутентификации
CREATE USER IF NOT EXISTS 'sar-bc'@'%' 
    IDENTIFIED VIA mysql_native_password USING PASSWORD('Vik159753');

-- Даем права
GRANT ALL PRIVILEGES ON mqtt_auth.* TO 'sar-bc'@'%';

-- Применяем изменения
FLUSH PRIVILEGES;

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

-- Создаем таблицу ACL
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

-- Выводим информацию
SELECT '✅ База данных MQTT успешно инициализирована' as '';
