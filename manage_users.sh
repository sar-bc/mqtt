#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка наличия Docker контейнера
check_container() {
    if ! docker ps | grep -q mqtt_cont; then
        echo -e "${RED}Ошибка: Контейнер mqtt_cont не запущен${NC}"
        echo "Запустите контейнер: docker-compose up -d"
        exit 1
    fi
}

# Создание пользователя
create_user() {
    echo -e "${GREEN}Создание нового пользователя MQTT${NC}"
    
    read -p "Введите имя пользователя: " username
    if [ -z "$username" ]; then
        echo -e "${RED}Имя пользователя не может быть пустым${NC}"
        exit 1
    fi
    
    read -s -p "Введите пароль: " password
    echo
    read -s -p "Подтвердите пароль: " password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}Пароли не совпадают${NC}"
        exit 1
    fi
    
    # Создание пользователя в контейнере
    docker exec -it mqtt_cont sh -c "mosquitto_passwd -b /mosquitto/config/passwords.txt $username $password"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Пользователь $username успешно создан${NC}"
        
        # Перезапускаем Mosquitto для применения изменений
        docker exec mqtt_cont sh -c "kill -HUP 1"
        echo -e "${GREEN}Настройки применены${NC}"
    else
        echo -e "${RED}Ошибка при создании пользователя${NC}"
    fi
}

# Удаление пользователя
delete_user() {
    echo -e "${YELLOW}Удаление пользователя MQTT${NC}"
    
    # Показываем список существующих пользователей
    echo "Существующие пользователи:"
    docker exec mqtt_cont cat /mosquitto/config/passwords.txt | cut -d: -f1
    
    read -p "Введите имя пользователя для удаления: " username
    
    if [ -z "$username" ]; then
        echo -e "${RED}Имя пользователя не может быть пустым${NC}"
        exit 1
    fi
    
    # Создаем временный файл без удаляемого пользователя
    docker exec mqtt_cont sh -c "cp /mosquitto/config/passwords.txt /mosquitto/config/passwords.txt.bak"
    docker exec mqtt_cont sh -c "grep -v '^$username:' /mosquitto/config/passwords.txt > /mosquitto/config/passwords.txt.tmp"
    docker exec mqtt_cont sh -c "mv /mosquitto/config/passwords.txt.tmp /mosquitto/config/passwords.txt"
    
    echo -e "${GREEN}Пользователь $username удален${NC}"
    
    # Перезапускаем Mosquitto для применения изменений
    docker exec mqtt_cont sh -c "kill -HUP 1"
    echo -e "${GREEN}Настройки применены${NC}"
}

# Список пользователей
list_users() {
    echo -e "${GREEN}Список пользователей MQTT:${NC}"
    echo "------------------------"
    docker exec mqtt_cont cat /mosquitto/config/passwords.txt | cut -d: -f1 | nl
    echo "------------------------"
}

# Смена пароля
change_password() {
    echo -e "${YELLOW}Смена пароля пользователя${NC}"
    
    read -p "Введите имя пользователя: " username
    
    if [ -z "$username" ]; then
        echo -e "${RED}Имя пользователя не может быть пустым${NC}"
        exit 1
    fi
    
    read -s -p "Введите новый пароль: " password
    echo
    read -s -p "Подтвердите пароль: " password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}Пароли не совпадают${NC}"
        exit 1
    fi
    
    docker exec -it mqtt_cont sh -c "mosquitto_passwd -b /mosquitto/config/passwords.txt $username $password"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Пароль для $username успешно изменен${NC}"
        docker exec mqtt_cont sh -c "kill -HUP 1"
    fi
}

# Главное меню
show_menu() {
    echo "==================================="
    echo "   MQTT USER MANAGEMENT SCRIPT"
    echo "==================================="
    echo "1) Создать пользователя"
    echo "2) Удалить пользователя"
    echo "3) Список пользователей"
    echo "4) Сменить пароль"
    echo "5) Выход"
    echo "==================================="
    read -p "Выберите действие (1-5): " choice
    
    case $choice in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) change_password ;;
        5) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}" ;;
    esac
}

# Проверяем наличие контейнера
check_container

# Бесконечный цикл меню
while true; do
    show_menu
    echo
    read -p "Нажмите Enter для продолжения..."
    clear
done