#!/bin/bash

# ============================================
# MQTT User Management for PostgreSQL (Bash)
# ============================================

# Конфигурация PostgreSQL
PG_HOST="localhost"
PG_PORT="5432"
PG_DB="mqtt_auth"
PG_USER="mqtt_admin"
PG_PASS="MqttSecurePass123!"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Проверка наличия psql
check_psql() {
    if ! command -v psql &> /dev/null; then
        echo -e "${RED}❌ psql not found. Please install postgresql-client:${NC}"
        echo "  Ubuntu/Debian: sudo apt install postgresql-client"
        echo "  CentOS/RHEL: sudo yum install postgresql"
        echo "  Alpine: apk add postgresql-client"
        exit 1
    fi
}

# Функция для выполнения SQL запросов
execute_sql() {
    local query="$1"
    PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -A -c "$query" 2>/dev/null
}

# Генерация bcrypt хеша (через Python, так как в Bash это сложно)
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

# Проверка наличия Python и bcrypt
check_python_bcrypt() {
    if ! python3 -c "import bcrypt" 2>/dev/null; then
        echo -e "${RED}❌ Python bcrypt module not found. Install it:${NC}"
        echo "  pip install bcrypt"
        exit 1
    fi
}

# Очистка экрана
clear_screen() {
    printf "\033c"
}

# Заголовок
show_header() {
    clear_screen
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     ${YELLOW}MQTT User Management for PostgreSQL${BLUE}               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Главное меню
show_menu() {
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

# Меню управления ACL
show_acl_menu() {
    clear_screen
    echo -e "${PURPLE}===================== УПРАВЛЕНИЕ ACL =====================${NC}"
    echo -e "${YELLOW}1.${NC} 📖 Показать все ACL"
    echo -e "${YELLOW}2.${NC} ➕ Добавить ACL"
    echo -e "${YELLOW}3.${NC} 🗑️  Удалить ACL"
    echo -e "${YELLOW}4.${NC} 🗑️  Удалить все ACL пользователя"
    echo -e "${YELLOW}5.${NC} 🔙 Назад в главное меню"
    echo -e "${PURPLE}========================================================${NC}"
    echo -n "Выберите действие [1-5]: "
}

# Список пользователей
list_users() {
    echo -e "\n${YELLOW}📋 Список пользователей:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    
    local result=$(execute_sql "
        SELECT 
            CASE WHEN enabled THEN '✅' ELSE '❌' END || ' ' ||
            CASE WHEN is_admin THEN '👑' ELSE '👤' END || ' ' ||
            username || ' (создан: ' || TO_CHAR(created_at, 'DD.MM.YYYY HH24:MI') || ')' ||
            CASE WHEN NOT enabled THEN ' [DISABLED]' ELSE '' END
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

# Список ACL
list_acls() {
    local username="$1"
    
    if [ -n "$username" ]; then
        echo -e "\n${YELLOW}📋 ACL для пользователя '$username':${NC}"
        local result=$(execute_sql "
            SELECT 
                CASE rw 
                    WHEN 1 THEN '📖 READ'
                    WHEN 2 THEN '✏️ WRITE'
                    WHEN 3 THEN '📝 READWRITE'
                END || ' → ' || topic ||
                ' (создан: ' || TO_CHAR(created_at, 'DD.MM.YYYY') || ')'
            FROM acls 
            WHERE username = '$username'
            ORDER BY topic;
        ")
    else
        echo -e "\n${YELLOW}📋 Все ACL:${NC}"
        local result=$(execute_sql "
            SELECT 
                username || ': ' ||
                CASE rw 
                    WHEN 1 THEN '📖 READ'
                    WHEN 2 THEN '✏️ WRITE'
                    WHEN 3 THEN '📝 READWRITE'
                END || ' → ' || topic
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
    
    if [ ${#password} -lt 6 ]; then
        echo -e "${RED}❌ Пароль должен быть не менее 6 символов${NC}"
        return
    fi
    
    echo -n "Сделать администратором? (y/N): "
    read is_admin
    
    local admin_flag="false"
    [[ "$is_admin" == "y" ]] && admin_flag="true"
    
    # Генерируем хеш пароля
    echo -n "🔐 Хеширование пароля... "
    local hash=$(generate_hash "$password")
    if [ $? -ne 0 ] || [ -z "$hash" ]; then
        echo -e "${RED}❌ Ошибка хеширования пароля${NC}"
        return
    fi
    echo -e "${GREEN}готово${NC}"
    
    # Добавляем в базу
    execute_sql "
        INSERT INTO users (username, password_hash, is_admin) 
        VALUES ('$username', '$hash', $admin_flag);
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Пользователь '$username' успешно создан${NC}"
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
        echo -e "${RED}❌ Ошибка хеширования пароля${NC}"
        return
    fi
    echo -e "${GREEN}готово${NC}"
    
    execute_sql "
        UPDATE users SET password_hash = '$hash' WHERE username = '$username';
    "
    
    echo -e "${GREEN}✅ Пароль изменен для '$username'${NC}"
}

# Переключение прав администратора
toggle_admin() {
    local username="$1"
    local make_admin="$2"
    
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -z "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' не найден${NC}"
        return
    fi
    
    execute_sql "UPDATE users SET is_admin = $make_admin WHERE username = '$username';"
    
    if [ "$make_admin" == "true" ]; then
        echo -e "${GREEN}✅ Пользователь '$username' теперь администратор${NC}"
    else
        echo -e "${GREEN}✅ У пользователя '$username' убраны права администратора${NC}"
    fi
}

# Включение/отключение пользователя
toggle_user() {
    local username="$1"
    local enable="$2"
    
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -z "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' не найден${NC}"
        return
    fi
    
    execute_sql "UPDATE users SET enabled = $enable WHERE username = '$username';"
    
    if [ "$enable" == "true" ]; then
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
        # ACL удалятся каскадно благодаря ON DELETE CASCADE
        execute_sql "DELETE FROM users WHERE username = '$username';"
        echo -e "${GREEN}✅ Пользователь '$username' удален${NC}"
    else
        echo "Операция отменена"
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
    
    case $rw_level in
        1) rw=1 ;;
        2) rw=2 ;;
        3) rw=3 ;;
        *) echo -e "${RED}❌ Неверный выбор${NC}"; return ;;
    esac
    
    # Проверяем, нет ли уже такого ACL
    local exists_acl=$(execute_sql "
        SELECT id FROM acls 
        WHERE username = '$username' AND topic = '$topic';
    ")
    
    if [ -n "$exists_acl" ]; then
        echo -e "${RED}❌ ACL для '$username' на '$topic' уже существует${NC}"
        return
    fi
    
    execute_sql "
        INSERT INTO acls (username, topic, rw) 
        VALUES ('$username', '$topic', $rw);
    "
    
    if [ $? -eq 0 ]; then
        local rw_text=""
        case $rw in
            1) rw_text="чтение" ;;
            2) rw_text="запись" ;;
            3) rw_text="чтение/запись" ;;
        esac
        echo -e "${GREEN}✅ ACL добавлен: $username может $rw_text на '$topic'${NC}"
    else
        echo -e "${RED}❌ Ошибка добавления ACL${NC}"
    fi
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
    
    # Показываем текущие ACL пользователя
    list_acls "$username"
    
    echo -n "Введите топик для удаления (или оставьте пустым для отмены): "
    read topic
    
    if [ -z "$topic" ]; then
        echo "Операция отменена"
        return
    fi
    
    execute_sql "
        DELETE FROM acls 
        WHERE username = '$username' AND topic = '$topic';
    "
    
    if [ $? -eq 0 ]; then
        if [ $(execute_sql "SELECT COUNT(*) FROM acls WHERE username = '$username' AND topic = '$topic';") -eq 0 ]; then
            echo -e "${GREEN}✅ ACL удален${NC}"
        else
            echo -e "${RED}❌ ACL не найден${NC}"
        fi
    fi
}

# Удаление всех ACL пользователя
delete_all_acls() {
    echo -e "\n${RED}🗑️  Удаление всех ACL пользователя${NC}"
    echo -n "Имя пользователя: "
    read username
    
    local exists=$(execute_sql "SELECT username FROM users WHERE username = '$username';")
    if [ -z "$exists" ]; then
        echo -e "${RED}❌ Пользователь '$username' не найден${NC}"
        return
    fi
    
    local count=$(execute_sql "SELECT COUNT(*) FROM acls WHERE username = '$username';")
    
    if [ "$count" -eq 0 ]; then
        echo "📭 У пользователя '$username' нет ACL"
        return
    fi
    
    echo -n "Удалить все $count ACL для '$username'? (y/N): "
    read confirm
    
    if [ "$confirm" == "y" ]; then
        execute_sql "DELETE FROM acls WHERE username = '$username';"
        echo -e "${GREEN}✅ Все ACL для '$username' удалены${NC}"
    else
        echo "Операция отменена"
    fi
}

# Управление ACL
manage_acl() {
    while true; do
        show_acl_menu
        read acl_choice
        
        case $acl_choice in
            1)
                clear_screen
                list_acls
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            2)
                clear_screen
                add_acl
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            3)
                clear_screen
                delete_acl
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            4)
                clear_screen
                delete_all_acls
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            5)
                return
                ;;
            *)
                echo -e "${RED}❌ Неверный выбор${NC}"
                sleep 1
                ;;
        esac
    done
}

# Проверка подключения к PostgreSQL
check_connection() {
    echo -n "🔍 Проверка подключения к PostgreSQL... "
    if execute_sql "SELECT 1;" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo -e "${RED}❌ Не удалось подключиться к PostgreSQL${NC}"
        echo "Проверьте:"
        echo "  - Запущен ли контейнер: docker ps | grep postgres"
        echo "  - Правильность параметров подключения"
        echo "  - Логи PostgreSQL: docker logs mqtt_postgres"
        return 1
    fi
}

# Главная функция
main() {
    # Проверки перед запуском
    check_psql
    check_python_bcrypt
    
    # Проверка подключения к БД
    if ! check_connection; then
        exit 1
    fi
    
    while true; do
        show_header
        show_menu
        read choice
        
        case $choice in
            1)
                clear_screen
                list_users
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            2)
                clear_screen
                add_user
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            3)
                clear_screen
                change_password
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            4)
                clear_screen
                echo -n "Имя пользователя для назначения администратором: "
                read username
                toggle_admin "$username" "true"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            5)
                clear_screen
                echo -n "Имя пользователя для снятия прав администратора: "
                read username
                toggle_admin "$username" "false"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            6)
                clear_screen
                echo -n "Имя пользователя для включения: "
                read username
                toggle_user "$username" "true"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            7)
                clear_screen
                echo -n "Имя пользователя для отключения: "
                read username
                toggle_user "$username" "false"
                echo -n "Нажмите Enter для продолжения..."
                read
                ;;
            8)
                clear_screen
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
