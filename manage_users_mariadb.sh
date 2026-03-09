#!/bin/bash

# ============================================
# MQTT User Management for MariaDB (Bash)
# ============================================

# Конфигурация MariaDB
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="mqtt_auth"
DB_USER="mqtt_user"
DB_PASS="MqttSecurePass123!"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Проверка наличия mysql клиента
check_mysql() {
    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}❌ mysql client not found. Please install:${NC}"
        echo "  Ubuntu/Debian: sudo apt install mariadb-client"
        echo "  Alpine: apk add mariadb-client"
        exit 1
    fi
}

# Функция для выполнения SQL запросов
execute_sql() {
    local query="$1"
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -s -N -e "$query" 2>/dev/null
}

# Генерация bcrypt хеша (через Python)
generate_hash() {
    local password="$1"
    python3 -c "
import bcrypt
import sys
try:
    salt = bcrypt.gensalt(rounds=12)
    hash = bcrypt.hashpw(sys.argv[1].encode('utf-8'), salt)
    print(hash.decode('utf-8'))
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" "$password"
}

# Проверка Python и bcrypt
check_python_bcrypt() {
    if ! python3 -c "import bcrypt" 2>/dev/null; then
        echo -e "${RED}❌ Python bcrypt module not found. Install it:${NC}"
        echo "  pip install bcrypt"
        exit 1
    fi
}

# Проверка подключения к MariaDB
check_connection() {
    echo -n "🔍 Проверка подключения к MariaDB... "
    if execute_sql "SELECT 1;" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}❌ Не удалось подключиться к MariaDB${NC}"
        echo "Проверьте:"
        echo "  - Запущен ли контейнер: docker ps | grep mariadb"
        echo "  - Логи: docker logs mqtt_mariadb"
        exit 1
    fi
}

# Показать меню
show_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     ${YELLOW}MQTT User Management for MariaDB${BLUE}                 ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}===================== ГЛАВНОЕ МЕНЮ =====================${NC}"
    echo -e "${YELLOW}1.${NC} 📋 Список пользователей"
    echo -e "${YELLOW}2.${NC} ➕ Добавить пользователя"
    echo -e "${YELLOW}3.${NC} 🔑 Сменить пароль"
    echo -e "${YELLOW}4.${NC} 👑 Сделать администратором"
    echo -e "${YELLOW}5.${NC} 👤 Убрать права администратора"
    echo -e "${YELLOW}6.${NC} ✅ Включить пользователя"
    echo -e "${YELLOW}7.${NC} ❌ Отключить пользователя"
    echo -e "${YELLOW}8.${NC} 🗑️  Удалить пользователя"
    echo -e "${YELLOW}9.${NC} 📋 Управление ACL (права доступа)"
    echo -e "${YELLOW}0.${NC} 🚪 Выход"
    echo -e "${CYAN}======================================================${NC}"
    echo -n "Выберите действие [0-9]: "
}

# Меню ACL
show_acl_menu() {
    clear
    echo -e "${PURPLE}===================== УПРАВЛЕНИЕ ACL =====================${NC}"
    echo -e "${YELLOW}1.${NC} 📖 Показать все ACL"
    echo -e "${YELLOW}2.${NC} ➕ Добавить ACL"
    echo -e "${YELLOW}3.${NC} 🗑️  Удалить ACL"
    echo -e "${YELLOW}4.${NC} 🔙 Назад в главное меню"
    echo -e "${PURPLE}========================================================${NC}"
    echo -n "Выберите действие [1-4]: "
}

# Список пользователей
list_users() {
    echo -e "\n${YELLOW}📋 Список пользователей:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    
    local result=$(execute_sql "
        SELECT 
            CONCAT(
                IF(enabled, '✅', '❌'), ' ',
                IF(is_admin, '👑', '👤'), ' ',
                username, ' (создан: ',
                DATE_FORMAT(created_at, '%d.%m.%Y %H:%i'), ')'
            )
        FROM users 
        ORDER BY username;
    ")
    
    if [ -z "$result" ]; then
        echo "  📭 Нет пользователей"
    else
        echo "$result" | while read line; do
            echo "  $line"
        done
    fi
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
}

# Добавление пользователя
add_user() {
    echo -e "\n${YELLOW}➕ Добавление нового пользователя${NC}"
    echo -n "Имя пользователя: "
    read username
    
    if [ -z "$username" ]; then
        echo -e "${RED}❌ Имя пользователя не может быть пустым${NC}"
        return
    fi
    
    # Проверяем существование
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -n "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' уже существует${NC}"
        return
    fi
    
    echo -n "Пароль: "
    read -s password
    echo
    echo -n "Подтвердите пароль: "
    read -s password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}❌ Пароли не совпадают${NC}"
        return
    fi
    
    echo -n "Сделать администратором? (y/N): "
    read is_admin
    
    local admin_flag="0"
    [[ "$is_admin" == "y" ]] && admin_flag="1"
    
    echo -n "🔐 Хеширование пароля... "
    local hash=$(generate_hash "$password")
    if [ $? -ne 0 ] || [ -z "$hash" ]; then
        echo -e "${RED}❌ Ошибка хеширования${NC}"
        return
    fi
    echo -e "${GREEN}готово${NC}"
    
    execute_sql "
        INSERT INTO users (username, password_hash, is_admin) 
        VALUES ('$username', '$hash', $admin_flag);
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Пользователь '$username' создан${NC}"
    else
        echo -e "${RED}❌ Ошибка создания пользователя${NC}"
    fi
}

# Смена пароля
change_password() {
    echo -e "\n${YELLOW}🔑 Смена пароля${NC}"
    echo -n "Имя пользователя: "
    read username
    
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -z "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' не найден${NC}"
        return
    fi
    
    echo -n "Новый пароль: "
    read -s password
    echo
    echo -n "Подтвердите пароль: "
    read -s password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}❌ Пароли не совпадают${NC}"
        return
    fi
    
    echo -n "🔐 Хеширование пароля... "
    local hash=$(generate_hash "$password")
    if [ $? -ne 0 ] || [ -z "$hash" ]; then
        echo -e "${RED}❌ Ошибка хеширования${NC}"
        return
    fi
    echo -e "${GREEN}готово${NC}"
    
    execute_sql "UPDATE users SET password_hash = '$hash' WHERE username = '$username';"
    echo -e "${GREEN}✅ Пароль изменен для '$username'${NC}"
}

# Переключение прав администратора
toggle_admin() {
    local username="$1"
    local make_admin="$2"
    
    execute_sql "UPDATE users SET is_admin = $make_admin WHERE username = '$username';"
    
    if [ "$make_admin" == "1" ]; then
        echo -e "${GREEN}✅ Пользователь '$username' теперь администратор${NC}"
    else
        echo -e "${GREEN}✅ У пользователя '$username' убраны права администратора${NC}"
    fi
}

# Включение/отключение пользователя
toggle_user() {
    local username="$1"
    local enable="$2"
    
    execute_sql "UPDATE users SET enabled = $enable WHERE username = '$username';"
    
    if [ "$enable" == "1" ]; then
        echo -e "${GREEN}✅ Пользователь '$username' включен${NC}"
    else
        echo -e "${GREEN}✅ Пользователь '$username' отключен${NC}"
    fi
}

# Удаление пользователя
delete_user() {
    echo -e "\n${RED}🗑️  Удаление пользователя${NC}"
    echo -n "Имя пользователя: "
    read username
    
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -z "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' не найден${NC}"
        return
    fi
    
    echo -n "Удалить пользователя '$username'? (y/N): "
    read confirm
    
    if [ "$confirm" == "y" ]; then
        execute_sql "DELETE FROM users WHERE username = '$username';"
        echo -e "${GREEN}✅ Пользователь '$username' удален${NC}"
    fi
}

# Добавление ACL
add_acl() {
    echo -e "\n${YELLOW}➕ Добавление ACL${NC}"
    echo -n "Имя пользователя: "
    read username
    
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -z "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' не найден${NC}"
        return
    fi
    
    echo -n "Топик (можно использовать + и #): "
    read topic
    
    echo "Уровень доступа:"
    echo "  1 - только чтение (read)"
    echo "  2 - только запись (write)"
    echo "  3 - чтение и запись (readwrite)"
    echo -n "Выбор [1-3]: "
    read rw_level
    
    execute_sql "
        INSERT INTO acls (username, topic, rw) 
        VALUES ('$username', '$topic', $rw_level)
        ON DUPLICATE KEY UPDATE rw = $rw_level;
    "
    
    local rw_text=""
    case $rw_level in
        1) rw_text="чтение" ;;
        2) rw_text="запись" ;;
        3) rw_text="чтение/запись" ;;
    esac
    echo -e "${GREEN}✅ ACL добавлен: $username может $rw_text на '$topic'${NC}"
}

# Список ACL
list_acls() {
    local username="$1"
    
    if [ -n "$username" ]; then
        echo -e "\n${YELLOW}📋 ACL для пользователя '$username':${NC}"
        local result=$(execute_sql "
            SELECT 
                CONCAT(
                    CASE rw 
                        WHEN 1 THEN '📖 READ'
                        WHEN 2 THEN '✏️ WRITE'
                        WHEN 3 THEN '📝 READWRITE'
                    END, ' → ', topic
                )
            FROM acls 
            WHERE username = '$username'
            ORDER BY topic;
        ")
    else
        echo -e "\n${YELLOW}📋 Все ACL:${NC}"
        local result=$(execute_sql "
            SELECT 
                CONCAT(
                    username, ': ',
                    CASE rw 
                        WHEN 1 THEN '📖 READ'
                        WHEN 2 THEN '✏️ WRITE'
                        WHEN 3 THEN '📝 READWRITE'
                    END, ' → ', topic
                )
            FROM acls 
            ORDER BY username, topic;
        ")
    fi
    
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    if [ -z "$result" ]; then
        echo "  📭 Нет правил доступа"
    else
        echo "$result" | while read line; do
            echo "  $line"
        done
    fi
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
}

# Удаление ACL
delete_acl() {
    echo -e "\n${YELLOW}🗑️  Удаление ACL${NC}"
    echo -n "Имя пользователя: "
    read username
    
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -z "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' не найден${NC}"
        return
    fi
    
    # Показываем текущие ACL
    list_acls "$username"
    
    echo -n "Введите топик для удаления: "
    read topic
    
    execute_sql "DELETE FROM acls WHERE username = '$username' AND topic = '$topic';"
    echo -e "${GREEN}✅ ACL удален${NC}"
}

# Управление ACL
manage_acl() {
    while true; do
        show_acl_menu
        read acl_choice
        
        case $acl_choice in
            1)
                clear
                list_acls
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            2)
                clear
                add_acl
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            3)
                clear
                delete_acl
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}❌ Неверный выбор${NC}"
                sleep 1
                ;;
        esac
    done
}

# Главная функция
main() {
    # Проверки перед запуском
    check_mysql
    check_python_bcrypt
    check_connection
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                clear
                list_users
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            2)
                clear
                add_user
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            3)
                clear
                change_password
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            4)
                clear
                echo -n "Имя пользователя для назначения администратором: "
                read username
                toggle_admin "$username" "1"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            5)
                clear
                echo -n "Имя пользователя для снятия прав администратора: "
                read username
                toggle_admin "$username" "0"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            6)
                clear
                echo -n "Имя пользователя для включения: "
                read username
                toggle_user "$username" "1"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            7)
                clear
                echo -n "Имя пользователя для отключения: "
                read username
                toggle_user "$username" "0"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            8)
                clear
                delete_user
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            9)
                manage_acl
                ;;
            0)
                echo -e "\n${GREEN}👋 До свидания!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Неверный выбор${NC}"
                sleep 1
                ;;
        esac
    done
}

# Запуск
main "$@"
