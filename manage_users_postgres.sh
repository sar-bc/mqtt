#!/bin/bash

# ============================================
# MQTT User Management Script (PostgreSQL version)
# WARNING: This script is for reference only!
# New C plugin requires PBKDF2 password hashes.
# Please use Python script for actual user management.
# ============================================

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ============================================
# КОНФИГУРАЦИЯ ПОДКЛЮЧЕНИЯ К БАЗЕ ДАННЫХ
# ============================================

# Приоритет: переменные окружения > значения по умолчанию
DB_HOST="${PGHOST:-localhost}"
DB_PORT="${PGPORT:-5432}"
DB_NAME="${PGDATABASE:-mqtt}"
DB_USER="${PGUSER:-mqtt_user}"
DB_PASSWORD="${PGPASSWORD:-}"  # Будет запрошена, если не задана

# ============================================
# ПРОВЕРКА ЗАВИСИМОСТЕЙ
# ============================================

check_dependencies() {
    if ! command -v psql &> /dev/null; then
        echo -e "${RED}❌ PostgreSQL клиент (psql) не установлен.${NC}"
        echo "Установите: sudo apt install postgresql-client"
        exit 1
    fi
}

# ============================================
# ФУНКЦИИ ДЛЯ РАБОТЫ С БАЗОЙ ДАННЫХ
# ============================================

get_db_password() {
    if [ -z "$DB_PASSWORD" ]; then
        echo -n "Введите пароль для пользователя PostgreSQL '$DB_USER': "
        read -s DB_PASSWORD
        echo
    fi
}

execute_sql() {
    local sql="$1"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c "$sql" 2>/dev/null
    return $?
}

execute_sql_verbose() {
    local sql="$1"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$sql"
    return $?
}

# ============================================
# ПРОВЕРКА СОВМЕСТИМОСТИ
# ============================================

check_compatibility() {
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║ ⚠️  ВНИМАНИЕ: Этот скрипт НЕ СОВМЕСТИМ с новым C-плагином!   ║${NC}"
    echo -e "${YELLOW}║    Он генерирует ТОЛЬКО bcrypt-хеши (старый формат).          ║${NC}"
    echo -e "${YELLOW}║    Для создания пользователей используйте:                   ║${NC}"
    echo -e "${YELLOW}║    python manage_users_postgres.py                            ║${NC}"
    echo -e "${YELLOW}║                                                                ║${NC}"
    echo -e "${YELLOW}║    Этот скрипт оставлен только для справки и просмотра данных.║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -n "Продолжить в режиме ТОЛЬКО ПРОСМОТРА? (y/N): "
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 0
    fi
    echo
}

# ============================================
# ФУНКЦИИ УПРАВЛЕНИЯ (ТОЛЬКО ПРОСМОТР)
# ============================================

list_users() {
    echo -e "${CYAN}📋 Список пользователей:${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    local result=$(execute_sql "SELECT id, username, 
        CASE WHEN is_superuser = 1 THEN '✅ Да' ELSE '❌ Нет' END as is_superuser,
        substring(password_hash, 1, 30) || '...' as password_preview
        FROM users ORDER BY id;")
    
    if [ -z "$result" ]; then
        echo -e "${YELLOW}Пользователи не найдены${NC}"
    else
        echo "$result" | while IFS='|' read -r id username superuser password; do
            printf "  ${GREEN}ID:${NC} %-3s ${GREEN}Логин:${NC} %-15s ${GREEN}Суперпользователь:${NC} %-3s ${GREEN}Хеш:${NC} %s\n" \
                "$id" "$username" "$superuser" "$password"
        done
    fi
    
    local count=$(execute_sql "SELECT COUNT(*) FROM users;")
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Всего пользователей:${NC} $count"
}

list_acls() {
    local username="$1"
    
    if [ -n "$username" ]; then
        echo -e "${CYAN}📋 ACL для пользователя '$username':${NC}"
        local where="WHERE username = '$username'"
    else
        echo -e "${CYAN}📋 Все ACL правила:${NC}"
        local where=""
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    local result=$(execute_sql "SELECT id, username, topic,
        CASE WHEN rw = 1 THEN '📖 Чтение'
             WHEN rw = 2 THEN '✏️ Запись'
             WHEN rw = 3 THEN '📖✏️ Чтение/Запись'
        END as rights
        FROM acls $where ORDER BY username, id;")
    
    if [ -z "$result" ]; then
        echo -e "${YELLOW}ACL правила не найдены${NC}"
    else
        echo "$result" | while IFS='|' read -r id username topic rights; do
            printf "  ${GREEN}ID:${NC} %-3s ${GREEN}Пользователь:${NC} %-15s ${GREEN}Топик:${NC} %-25s ${GREEN}Права:${NC} %s\n" \
                "$id" "$username" "$topic" "$rights"
        done
    fi
    
    local count=$(execute_sql "SELECT COUNT(*) FROM acls $where;")
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Всего правил:${NC} $count"
}

show_user_info() {
    local username="$1"
    
    echo -e "${CYAN}📊 Информация о пользователе '$username':${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    # Основная информация
    local user_info=$(execute_sql "SELECT id, 
        CASE WHEN is_superuser = 1 THEN 'Да' ELSE 'Нет' END as superuser
        FROM users WHERE username = '$username';")
    
    if [ -z "$user_info" ]; then
        echo -e "${RED}❌ Пользователь не найден${NC}"
        return 1
    fi
    
    IFS='|' read -r id superuser <<< "$user_info"
    echo -e "  ${GREEN}ID:${NC} $id"
    echo -e "  ${GREEN}Логин:${NC} $username"
    echo -e "  ${GREEN}Суперпользователь:${NC} $superuser"
    
    # ACL пользователя
    echo
    echo -e "${CYAN}Права доступа:${NC}"
    local acls=$(execute_sql "SELECT topic,
        CASE WHEN rw = 1 THEN 'Чтение'
             WHEN rw = 2 THEN 'Запись'
             WHEN rw = 3 THEN 'Чтение/Запись'
        END as rights
        FROM acls WHERE username = '$username' ORDER BY topic;")
    
    if [ -z "$acls" ]; then
        echo -e "  ${YELLOW}Нет правил доступа${NC}"
    else
        echo "$acls" | while IFS='|' read -r topic rights; do
            printf "  ${GREEN}Топик:${NC} %-30s ${GREEN}Права:${NC} %s\n" "$topic" "$rights"
        done
    fi
}

check_connection() {
    echo -e "${CYAN}🔌 Проверка подключения к базе данных...${NC}"
    
    if execute_sql "SELECT 1;" > /dev/null; then
        local version=$(execute_sql "SELECT version();")
        echo -e "${GREEN}✅ Подключение успешно!${NC}"
        echo -e "  Версия PostgreSQL: $version"
        return 0
    else
        echo -e "${RED}❌ Ошибка подключения к базе данных${NC}"
        echo -e "${YELLOW}Проверьте параметры подключения:${NC}"
        echo "  Хост: $DB_HOST"
        echo "  Порт: $DB_PORT"
        echo "  База: $DB_NAME"
        echo "  Пользователь: $DB_USER"
        return 1
    fi
}

# ============================================
# ПРЕДУПРЕЖДЕНИЕ О НЕВОЗМОЖНОСТИ СОЗДАНИЯ
# ============================================

show_create_warning() {
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ ⚠️  НЕВОЗМОЖНО СОЗДАТЬ ПОЛЬЗОВАТЕЛЯ ЧЕРЕЗ ЭТОТ СКРИПТ    ║${NC}"
    echo -e "${RED}║    Новый C-плагин требует PBKDF2-хеши паролей.           ║${NC}"
    echo -e "${RED}║    Используйте Python-скрипт:                             ║${NC}"
    echo -e "${RED}║    python manage_users_postgres.py add -u username       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
}

show_update_warning() {
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ ⚠️  НЕВОЗМОЖНО ИЗМЕНИТЬ ПАРОЛЬ ЧЕРЕЗ ЭТОТ СКРИПТ         ║${NC}"
    echo -e "${RED}║    Новый C-плагин требует PBKDF2-хеши паролей.           ║${NC}"
    echo -e "${RED}║    Используйте Python-скрипт:                             ║${NC}"
    echo -e "${RED}║    python manage_users_postgres.py passwd -u username    ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
}

# ============================================
# ГЛАВНОЕ МЕНЮ
# ============================================

show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     MQTT Broker - Управление пользователями (PostgreSQL)  ║${NC}"
    echo -e "${BLUE}║           ${YELLOW}(РЕЖИМ ТОЛЬКО ПРОСМОТРА)${BLUE}                ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║  ${WHITE}1${BLUE}) ${GREEN}📋 Список пользователей${NC}                        ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${WHITE}2${BLUE}) ${GREEN}📋 Список всех ACL${NC}                             ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${WHITE}3${BLUE}) ${GREEN}👤 Показать информацию о пользователе${NC}          ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${WHITE}4${BLUE}) ${GREEN}🔌 Проверить подключение к БД${NC}                  ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${WHITE}5${BLUE}) ${RED}⚠️  Создать пользователя (НЕ РАБОТАЕТ)${NC}           ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${WHITE}6${BLUE}) ${RED}⚠️  Изменить пароль (НЕ РАБОТАЕТ)${NC}                ${BLUE}║${NC}"
    echo -e "${BLUE}║  ${WHITE}0${BLUE}) ${RED}🚪 Выход${NC}                                        ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo -n "Выберите действие [0-6]: "
}

# ============================================
# ОСНОВНОЙ ЦИКЛ
# ============================================

main() {
    check_dependencies
    check_compatibility
    get_db_password
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                list_users
                ;;
            2)
                echo -n "Показать ACL для конкретного пользователя? (оставьте пустым для всех): "
                read username
                list_acls "$username"
                ;;
            3)
                echo -n "Введите имя пользователя: "
                read username
                show_user_info "$username"
                ;;
            4)
                check_connection
                ;;
            5)
                show_create_warning
                ;;
            6)
                show_update_warning
                ;;
            0)
                echo -e "${GREEN}👋 До свидания!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Неверный выбор. Пожалуйста, выберите 0-6${NC}"
                ;;
        esac
        
        echo
        echo -n "Нажмите Enter, чтобы продолжить..."
        read
    done
}

# Запуск основной функции
main "$@"
