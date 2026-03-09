#!/bin/bash

# Конфигурация
CONTAINER_NAME="mqtt_cont"
DB_PATH="/mosquitto/config/mqtt_users.db"
SQLITE="docker exec -i $CONTAINER_NAME sqlite3 $DB_PATH"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка доступности контейнера
check_container() {
    if ! docker ps | grep -q $CONTAINER_NAME; then
        echo -e "${RED}❌ Контейнер $CONTAINER_NAME не запущен${NC}"
        echo "Запустите: docker-compose up -d"
        exit 1
    fi
}

# Инициализация базы данных
init_db() {
    echo -e "${BLUE}Инициализация базы данных...${NC}"
    $SQLITE <<EOF
CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    password TEXT NOT NULL,
    superuser INTEGER DEFAULT 0,
    enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS acls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    topic TEXT NOT NULL,
    rw INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(username) REFERENCES users(username) ON DELETE CASCADE,
    UNIQUE(username, topic)
);
EOF
    echo -e "${GREEN}✅ База данных инициализирована${NC}"
}

# Генерация хеша пароля (через np из контейнера)
generate_hash() {
    local password=$1
    docker exec $CONTAINER_NAME /mosquitto/plugins/np "$password"
}

# Показать меню
show_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}   MQTT User Management (SQLite)${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "1. 📋 Список пользователей"
    echo "2. ➕ Добавить пользователя"
    echo "3. ❌ Удалить пользователя"
    echo "4. 🔑 Сменить пароль"
    echo "5. ✅ Включить пользователя"
    echo "6. ❌ Отключить пользователя"
    echo "7. 📋 Управление ACL"
    echo "8. 💾 Инициализировать БД"
    echo "9. 🚪 Выход"
    echo -e "${BLUE}========================================${NC}"
}

# Список пользователей
list_users() {
    echo -e "\n${YELLOW}📋 Список пользователей:${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    $SQLITE "SELECT 
        CASE WHEN enabled=1 THEN '✅' ELSE '❌' END || ' ' ||
        CASE WHEN superuser=1 THEN '👑' ELSE '👤' END || ' ' ||
        username || ' (создан: ' || substr(created_at,1,16) || ')' 
        FROM users ORDER BY username;" | sed 's/^/  /'
    echo -e "${BLUE}----------------------------------------${NC}"
}

# Добавить пользователя
add_user() {
    read -p "Имя пользователя: " username
    read -s -p "Пароль: " password
    echo
    read -s -p "Повторите пароль: " password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}❌ Пароли не совпадают${NC}"
        return
    fi
    
    read -p "Суперпользователь? (y/N): " super
    super_val=0
    [ "$super" = "y" ] && super_val=1
    
    # Генерируем хеш
    hash=$(generate_hash "$password")
    
    # Добавляем в БД
    $SQLITE "INSERT INTO users (username, password, superuser) VALUES ('$username', '$hash', $super_val);"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Пользователь $username создан${NC}"
    else
        echo -e "${RED}❌ Ошибка создания пользователя${NC}"
    fi
}

# Управление ACL
manage_acl() {
    while true; do
        clear
        echo -e "${YELLOW}📋 Управление ACL${NC}"
        echo "1. 📖 Показать все ACL"
        echo "2. ➕ Добавить ACL"
        echo "3. ❌ Удалить ACL"
        echo "4. 🔙 Назад"
        echo -e "${BLUE}----------------------------------------${NC}"
        
        read -p "Выбор [1-4]: " acl_choice
        
        case $acl_choice in
            1)
                echo -e "\n${YELLOW}Все ACL:${NC}"
                $SQLITE "SELECT username, topic, 
                    CASE rw WHEN 1 THEN '📖 read' WHEN 2 THEN '✏️ write' ELSE '📝 read/write' END 
                    FROM acls ORDER BY username, topic;" | 
                    while IFS='|' read user topic access; do
                        echo "  $user: $topic [$access]"
                    done
                read -p "Нажмите Enter для продолжения..."
                ;;
            2)
                read -p "Имя пользователя: " username
                read -p "Топик (можно использовать + и #): " topic
                echo "Уровень доступа:"
                echo "  1 - только чтение"
                echo "  2 - только запись"
                echo "  3 - чтение и запись"
                read -p "Выбор [1-3]: " rw
                $SQLITE "INSERT INTO acls (username, topic, rw) VALUES ('$username', '$topic', $rw);"
                echo -e "${GREEN}✅ ACL добавлен${NC}"
                read -p "Нажмите Enter для продолжения..."
                ;;
            3)
                read -p "Имя пользователя: " username
                read -p "Топик (оставьте пустым для удаления всех): " topic
                if [ -z "$topic" ]; then
                    $SQLITE "DELETE FROM acls WHERE username = '$username';"
                    echo -e "${GREEN}✅ Все ACL для $username удалены${NC}"
                else
                    $SQLITE "DELETE FROM acls WHERE username = '$username' AND topic = '$topic';"
                    echo -e "${GREEN}✅ ACL удален${NC}"
                fi
                read -p "Нажмите Enter для продолжения..."
                ;;
            4)
                break
                ;;
        esac
    done
}

# Основной цикл
main() {
    check_container
    
    while true; do
        show_menu
        read -p "Выберите действие [1-9]: " choice
        
        case $choice in
            1)
                list_users
                read -p "Нажмите Enter для продолжения..."
                ;;
            2)
                add_user
                read -p "Нажмите Enter для продолжения..."
                ;;
            3)
                read -p "Имя пользователя для удаления: " username
                read -p "Удалить пользователя $username? (y/N): " confirm
                if [ "$confirm" = "y" ]; then
                    $SQLITE "DELETE FROM users WHERE username = '$username';"
                    echo -e "${GREEN}✅ Пользователь удален${NC}"
                fi
                read -p "Нажмите Enter для продолжения..."
                ;;
            4)
                read -p "Имя пользователя: " username
                read -s -p "Новый пароль: " password
                echo
                read -s -p "Повторите пароль: " password2
                echo
                if [ "$password" = "$password2" ]; then
                    hash=$(generate_hash "$password")
                    $SQLITE "UPDATE users SET password = '$hash' WHERE username = '$username';"
                    echo -e "${GREEN}✅ Пароль изменен${NC}"
                else
                    echo -e "${RED}❌ Пароли не совпадают${NC}"
                fi
                read -p "Нажмите Enter для продолжения..."
                ;;
            5)
                read -p "Имя пользователя: " username
                $SQLITE "UPDATE users SET enabled = 1 WHERE username = '$username';"
                echo -e "${GREEN}✅ Пользователь включен${NC}"
                read -p "Нажмите Enter для продолжения..."
                ;;
            6)
                read -p "Имя пользователя: " username
                $SQLITE "UPDATE users SET enabled = 0 WHERE username = '$username';"
                echo -e "${GREEN}✅ Пользователь отключен${NC}"
                read -p "Нажмите Enter для продолжения..."
                ;;
            7)
                manage_acl
                ;;
            8)
                init_db
                read -p "Нажмите Enter для продолжения..."
                ;;
            9)
                echo -e "${GREEN}До свидания!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор${NC}"
                read -p "Нажмите Enter для продолжения..."
                ;;
        esac
    done
}

# Запуск
main