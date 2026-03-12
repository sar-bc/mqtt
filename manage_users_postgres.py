#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
MQTT User Management Script for PostgreSQL
Supports PBKDF2 password hashes for mosquitto-auth-plug (C plugin)

Usage:
    python manage_users_postgres.py -h
    python manage_users_postgres.py list
    python manage_users_postgres.py add -u username
    python manage_users_postgres.py del -u username
    python manage_users_postgres.py passwd -u username
    python manage_users_postgres.py add-acl -u username -t "topic/#" -r 1
    python manage_users_postgres.py del-acl -a acl_id
    python manage_users_postgres.py list-acls [-u username]
"""

import argparse
import getpass
import psycopg2
from psycopg2 import sql, OperationalError
import sys
import os
from passlib.hash import pbkdf2_sha256

# ============================================
# КОНФИГУРАЦИЯ ПОДКЛЮЧЕНИЯ К БАЗЕ ДАННЫХ
# ============================================

DB_CONFIG = {
    'host': os.environ.get('PGHOST', 'localhost'),
    'port': os.environ.get('PGPORT', '5432'),
    'database': os.environ.get('PGDATABASE', 'mqtt'),
    'user': os.environ.get('PGUSER', 'mqtt_user'),
    'password': os.environ.get('PGPASSWORD', 'Vik159753')  
}

# ============================================
# ЦВЕТА ДЛЯ ВЫВОДА (ОПЦИОНАЛЬНО)
# ============================================

try:
    from colorama import init, Fore, Style
    init()
    COLORS = True
except ImportError:
    COLORS = False
    # Заглушки для цветов
    class Fore:
        RED = ''; GREEN = ''; YELLOW = ''; BLUE = ''; CYAN = ''; MAGENTA = ''
    class Style:
        RESET_ALL = ''

# ============================================
# ФУНКЦИИ ДЛЯ РАБОТЫ С БАЗОЙ ДАННЫХ
# ============================================

def get_db_connection():
    """Установка соединения с базой данных"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except OperationalError as e:
        print(f"{Fore.RED}❌ Ошибка подключения к базе данных:{Style.RESET_ALL}")
        print(f"  {e}")
        print(f"\n{Fore.YELLOW}Проверьте параметры подключения:{Style.RESET_ALL}")
        print(f"  Хост: {DB_CONFIG['host']}")
        print(f"  Порт: {DB_CONFIG['port']}")
        print(f"  База: {DB_CONFIG['database']}")
        print(f"  Пользователь: {DB_CONFIG['user']}")
        sys.exit(1)

def execute_query(query, params=None, fetch=False, commit=False):
    """Выполнение SQL-запроса с обработкой ошибок"""
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(query, params)
        
        result = None
        if fetch:
            result = cur.fetchall()
        if commit:
            conn.commit()
        
        cur.close()
        return result
    except Exception as e:
        print(f"{Fore.RED}❌ Ошибка выполнения запроса:{Style.RESET_ALL}")
        print(f"  {e}")
        if conn:
            conn.rollback()
        sys.exit(1)
    finally:
        if conn:
            conn.close()

# ============================================
# ФУНКЦИИ ХЕШИРОВАНИЯ ПАРОЛЕЙ (PBKDF2 для C-плагина)
# ============================================

def hash_password(password):
    """
    Генерирует хеш пароля в формате, совместимом с mosquitto-auth-plug (C plugin)
    Формат: PBKDF2$sha256$901$<salt>$<hash>
    
    Аргументы:
        password: строка с паролем
        
    Возвращает:
        строку с хешем в формате плагина
    """
    # passlib возвращает строку вида $pbkdf2-sha256$901$<salt>$<hash>
    hash_str = pbkdf2_sha256.using(rounds=901, salt_size=16).hash(password)
    
    # Преобразуем в нужный формат: убираем первый '$' и меняем разделители
    # $pbkdf2-sha256$901$<salt>$<hash> -> PBKDF2$sha256$901$<salt>$<hash>
    parts = hash_str[1:].split('$')  # ['pbkdf2-sha256', '901', '<salt>', '<hash>']
    algo = parts[0].replace('pbkdf2-', '')  # 'sha256'
    return f"PBKDF2${algo}${parts[1]}${parts[2]}${parts[3]}"

def verify_password(password, password_hash):
    """
    Проверяет соответствие пароля и хеша (для тестирования)
    
    Аргументы:
        password: строка с паролем
        password_hash: хеш из базы данных
        
    Возвращает:
        True если пароль соответствует хешу
    """
    try:
        # Конвертируем формат плагина обратно в формат passlib
        # PBKDF2$sha256$901$<salt>$<hash> -> $pbkdf2-sha256$901$<salt>$<hash>
        if password_hash.startswith('PBKDF2$'):
            parts = password_hash.split('$')
            # parts = ['PBKDF2', 'sha256', '901', '<salt>', '<hash>']
            passlib_hash = f"$pbkdf2-{parts[1]}${parts[2]}${parts[3]}${parts[4]}"
            return pbkdf2_sha256.verify(password, passlib_hash)
        return False
    except:
        return False

# ============================================
# ФУНКЦИИ УПРАВЛЕНИЯ ПОЛЬЗОВАТЕЛЯМИ
# ============================================

def list_users():
    """Вывод списка всех пользователей"""
    query = """
        SELECT id, username, 
               CASE WHEN is_superuser = 1 THEN '✅ Да' ELSE '❌ Нет' END as is_superuser,
               SUBSTRING(password_hash, 1, 50) || '...' as password_preview
        FROM users 
        ORDER BY id
    """
    users = execute_query(query, fetch=True)
    
    print(f"\n{Fore.CYAN}📋 Список пользователей:{Style.RESET_ALL}")
    print(f"{Fore.BLUE}{'='*60}{Style.RESET_ALL}")
    
    if not users:
        print(f"{Fore.YELLOW}Пользователи не найдены{Style.RESET_ALL}")
    else:
        for user in users:
            print(f"  {Fore.GREEN}ID:{Style.RESET_ALL} {user[0]:<3} "
                  f"{Fore.GREEN}Логин:{Style.RESET_ALL} {user[1]:<15} "
                  f"{Fore.GREEN}Суперпользователь:{Style.RESET_ALL} {user[2]:<3}")
            print(f"  {Fore.GREEN}Хеш:{Style.RESET_ALL} {user[3]}")
            print()
    
    # Подсчет общего количества
    count = execute_query("SELECT COUNT(*) FROM users", fetch=True)[0][0]
    print(f"{Fore.BLUE}{'='*60}{Style.RESET_ALL}")
    print(f"{Fore.GREEN}Всего пользователей:{Style.RESET_ALL} {count}")

def add_user(username, is_superuser=False):
    """Добавление нового пользователя"""
    # Проверяем, существует ли уже пользователь
    check = execute_query(
        "SELECT id FROM users WHERE username = %s",
        (username,),
        fetch=True
    )
    
    if check:
        print(f"{Fore.RED}❌ Пользователь '{username}' уже существует{Style.RESET_ALL}")
        return
    
    # Запрашиваем пароль
    print(f"{Fore.YELLOW}Создание пользователя '{username}'{Style.RESET_ALL}")
    while True:
        password = getpass.getpass("Введите пароль: ")
        if len(password) < 4:
            print(f"{Fore.RED}Пароль должен быть не менее 4 символов{Style.RESET_ALL}")
            continue
        password2 = getpass.getpass("Повторите пароль: ")
        if password != password2:
            print(f"{Fore.RED}Пароли не совпадают{Style.RESET_ALL}")
            continue
        break
    
    # Хешируем пароль
    password_hash = hash_password(password)
    
    # Добавляем пользователя
    query = """
        INSERT INTO users (username, password_hash, is_superuser)
        VALUES (%s, %s, %s)
    """
    execute_query(query, (username, password_hash, 1 if is_superuser else 0), commit=True)
    
    print(f"{Fore.GREEN}✅ Пользователь '{username}' успешно создан{Style.RESET_ALL}")
    print(f"{Fore.YELLOW}Формат хеша: PBKDF2 (совместим с C-плагином){Style.RESET_ALL}")
    
    # Показываем созданного пользователя
    show_user_info(username)

def delete_user(username):
    """Удаление пользователя"""
    # Проверяем существование
    check = execute_query(
        "SELECT id FROM users WHERE username = %s",
        (username,),
        fetch=True
    )
    
    if not check:
        print(f"{Fore.RED}❌ Пользователь '{username}' не найден{Style.RESET_ALL}")
        return
    
    # Запрашиваем подтверждение
    print(f"{Fore.RED}⚠️  ВНИМАНИЕ: Будет удален пользователь '{username}' и все его ACL!{Style.RESET_ALL}")
    confirm = input("Продолжить? (y/N): ")
    if confirm.lower() != 'y':
        print(f"{Fore.YELLOW}Операция отменена{Style.RESET_ALL}")
        return
    
    # Удаляем ACL пользователя
    execute_query("DELETE FROM acls WHERE username = %s", (username,), commit=True)
    
    # Удаляем пользователя
    execute_query("DELETE FROM users WHERE username = %s", (username,), commit=True)
    
    print(f"{Fore.GREEN}✅ Пользователь '{username}' удален{Style.RESET_ALL}")

def change_password(username):
    """Изменение пароля пользователя"""
    # Проверяем существование
    check = execute_query(
        "SELECT id FROM users WHERE username = %s",
        (username,),
        fetch=True
    )
    
    if not check:
        print(f"{Fore.RED}❌ Пользователь '{username}' не найден{Style.RESET_ALL}")
        return
    
    # Запрашиваем новый пароль
    print(f"{Fore.YELLOW}Изменение пароля для '{username}'{Style.RESET_ALL}")
    while True:
        password = getpass.getpass("Введите новый пароль: ")
        if len(password) < 4:
            print(f"{Fore.RED}Пароль должен быть не менее 4 символов{Style.RESET_ALL}")
            continue
        password2 = getpass.getpass("Повторите пароль: ")
        if password != password2:
            print(f"{Fore.RED}Пароли не совпадают{Style.RESET_ALL}")
            continue
        break
    
    # Хешируем пароль
    password_hash = hash_password(password)
    
    # Обновляем пароль
    execute_query(
        "UPDATE users SET password_hash = %s WHERE username = %s",
        (password_hash, username),
        commit=True
    )
    
    print(f"{Fore.GREEN}✅ Пароль для '{username}' успешно изменен{Style.RESET_ALL}")
    print(f"{Fore.YELLOW}Новый хеш (PBKDF2):{Style.RESET_ALL} {password_hash[:50]}...")

def show_user_info(username):
    """Показать информацию о конкретном пользователе"""
    # Основная информация
    user = execute_query(
        """SELECT id, 
                  CASE WHEN is_superuser = 1 THEN 'Да' ELSE 'Нет' END as superuser,
                  password_hash
           FROM users WHERE username = %s""",
        (username,),
        fetch=True
    )
    
    if not user:
        print(f"{Fore.RED}❌ Пользователь '{username}' не найден{Style.RESET_ALL}")
        return
    
    print(f"\n{Fore.CYAN}📊 Информация о пользователе '{username}':{Style.RESET_ALL}")
    print(f"{Fore.BLUE}{'='*60}{Style.RESET_ALL}")
    print(f"  {Fore.GREEN}ID:{Style.RESET_ALL} {user[0][0]}")
    print(f"  {Fore.GREEN}Логин:{Style.RESET_ALL} {username}")
    print(f"  {Fore.GREEN}Суперпользователь:{Style.RESET_ALL} {user[0][1]}")
    print(f"  {Fore.GREEN}Хеш пароля:{Style.RESET_ALL} {user[0][2][:60]}...")
    
    # ACL пользователя
    acls = execute_query(
        """SELECT id, topic,
                  CASE WHEN rw = 1 THEN 'Чтение'
                       WHEN rw = 2 THEN 'Запись'
                       WHEN rw = 3 THEN 'Чтение/Запись'
                  END as rights
           FROM acls WHERE username = %s
           ORDER BY topic""",
        (username,),
        fetch=True
    )
    
    print(f"\n{Fore.CYAN}📋 Права доступа (ACL):{Style.RESET_ALL}")
    if not acls:
        print(f"  {Fore.YELLOW}Нет правил доступа{Style.RESET_ALL}")
    else:
        for acl in acls:
            print(f"  {Fore.GREEN}ID:{Style.RESET_ALL} {acl[0]:<3} "
                  f"{Fore.GREEN}Топик:{Style.RESET_ALL} {acl[1]:<30} "
                  f"{Fore.GREEN}Права:{Style.RESET_ALL} {acl[2]}")
    
    print(f"{Fore.BLUE}{'='*60}{Style.RESET_ALL}")

# ============================================
# ФУНКЦИИ УПРАВЛЕНИЯ ACL
# ============================================

def add_acl(username, topic, rw):
    """Добавление правила ACL"""
    # Проверяем существование пользователя
    user = execute_query(
        "SELECT id FROM users WHERE username = %s",
        (username,),
        fetch=True
    )
    
    if not user:
        print(f"{Fore.RED}❌ Пользователь '{username}' не найден{Style.RESET_ALL}")
        return
    
    # Проверяем, не существует ли уже такое правило
    existing = execute_query(
        "SELECT id FROM acls WHERE username = %s AND topic = %s AND rw = %s",
        (username, topic, rw),
        fetch=True
    )
    
    if existing:
        print(f"{Fore.YELLOW}⚠️  Правило уже существует (ID: {existing[0][0]}){Style.RESET_ALL}")
        return
    
    # Добавляем правило
    execute_query(
        "INSERT INTO acls (username, topic, rw) VALUES (%s, %s, %s)",
        (username, topic, rw),
        commit=True
    )
    
    rights = {1: "чтение", 2: "запись", 3: "чтение/запись"}[rw]
    print(f"{Fore.GREEN}✅ Правило ACL добавлено:{Style.RESET_ALL}")
    print(f"  Пользователь: {username}")
    print(f"  Топик: {topic}")
    print(f"  Права: {rights}")

def delete_acl(acl_id):
    """Удаление правила ACL по ID"""
    # Проверяем существование правила
    acl = execute_query(
        "SELECT id, username, topic FROM acls WHERE id = %s",
        (acl_id,),
        fetch=True
    )
    
    if not acl:
        print(f"{Fore.RED}❌ Правило ACL с ID {acl_id} не найдено{Style.RESET_ALL}")
        return
    
    # Запрашиваем подтверждение
    print(f"{Fore.RED}⚠️  Удаление правила ACL:{Style.RESET_ALL}")
    print(f"  ID: {acl[0][0]}")
    print(f"  Пользователь: {acl[0][1]}")
    print(f"  Топик: {acl[0][2]}")
    
    confirm = input("Продолжить? (y/N): ")
    if confirm.lower() != 'y':
        print(f"{Fore.YELLOW}Операция отменена{Style.RESET_ALL}")
        return
    
    # Удаляем правило
    execute_query("DELETE FROM acls WHERE id = %s", (acl_id,), commit=True)
    print(f"{Fore.GREEN}✅ Правило ACL удалено{Style.RESET_ALL}")

def list_acls(username=None):
    """Вывод списка ACL правил"""
    if username:
        query = """
            SELECT a.id, a.username, a.topic,
                   CASE WHEN a.rw = 1 THEN '📖 Чтение'
                        WHEN a.rw = 2 THEN '✏️ Запись'
                        WHEN a.rw = 3 THEN '📖✏️ Чтение/Запись'
                   END as rights
            FROM acls a
            WHERE a.username = %s
            ORDER BY a.username, a.id
        """
        params = (username,)
        title = f"ACL для пользователя '{username}'"
    else:
        query = """
            SELECT a.id, a.username, a.topic,
                   CASE WHEN a.rw = 1 THEN '📖 Чтение'
                        WHEN a.rw = 2 THEN '✏️ Запись'
                        WHEN a.rw = 3 THEN '📖✏️ Чтение/Запись'
                   END as rights
            FROM acls a
            ORDER BY a.username, a.id
        """
        params = None
        title = "Все ACL правила"
    
    acls = execute_query(query, params, fetch=True)
    
    print(f"\n{Fore.CYAN}📋 {title}:{Style.RESET_ALL}")
    print(f"{Fore.BLUE}{'='*80}{Style.RESET_ALL}")
    
    if not acls:
        print(f"{Fore.YELLOW}ACL правила не найдены{Style.RESET_ALL}")
    else:
        for acl in acls:
            print(f"  {Fore.GREEN}ID:{Style.RESET_ALL} {acl[0]:<4} "
                  f"{Fore.GREEN}Пользователь:{Style.RESET_ALL} {acl[1]:<15} "
                  f"{Fore.GREEN}Топик:{Style.RESET_ALL} {acl[2]:<30}")
            print(f"  {' ' * 6}{Fore.GREEN}Права:{Style.RESET_ALL} {acl[3]}")
            print()
    
    # Подсчет количества
    if username:
        count = execute_query(
            "SELECT COUNT(*) FROM acls WHERE username = %s",
            (username,),
            fetch=True
        )[0][0]
    else:
        count = execute_query("SELECT COUNT(*) FROM acls", fetch=True)[0][0]
    
    print(f"{Fore.BLUE}{'='*80}{Style.RESET_ALL}")
    print(f"{Fore.GREEN}Всего правил:{Style.RESET_ALL} {count}")

# ============================================
# ПРОВЕРКА ПОДКЛЮЧЕНИЯ
# ============================================

def check_connection():
    """Проверка подключения к базе данных"""
    print(f"{Fore.CYAN}🔌 Проверка подключения к базе данных...{Style.RESET_ALL}")
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT version();")
        version = cur.fetchone()[0]
        cur.close()
        conn.close()
        
        print(f"{Fore.GREEN}✅ Подключение успешно!{Style.RESET_ALL}")
        print(f"  Версия PostgreSQL: {version}")
        
        # Проверяем наличие таблиц
        cur = conn.cursor()
        cur.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('users', 'acls')
        """)
        tables = [row[0] for row in cur.fetchall()]
        
        if 'users' in tables and 'acls' in tables:
            print(f"{Fore.GREEN}✅ Таблицы users и acls найдены{Style.RESET_ALL}")
        else:
            print(f"{Fore.YELLOW}⚠️  Таблицы users и/или acls не найдены{Style.RESET_ALL}")
            print("  Убедитесь, что init.sql выполнен при создании контейнера")
        
        return True
    except Exception as e:
        print(f"{Fore.RED}❌ Ошибка подключения:{Style.RESET_ALL}")
        print(f"  {e}")
        return False

# ============================================
# ТЕСТИРОВАНИЕ ХЕШЕЙ (ДЛЯ ОТЛАДКИ)
# ============================================

def test_password_hash(password):
    """Тестовая функция для проверки генерации хешей"""
    print(f"{Fore.CYAN}🔬 Тестирование генерации хеша пароля:{Style.RESET_ALL}")
    print(f"  Пароль: {password}")
    
    hash_value = hash_password(password)
    print(f"  {Fore.GREEN}Хеш (PBKDF2):{Style.RESET_ALL} {hash_value}")
    
    # Проверяем валидацию
    if verify_password(password, hash_value):
        print(f"  {Fore.GREEN}✅ Проверка пароля пройдена{Style.RESET_ALL}")
    else:
        print(f"  {Fore.RED}❌ Ошибка проверки пароля{Style.RESET_ALL}")
    
    return hash_value

# ============================================
# ПАРСЕР КОМАНДНОЙ СТРОКИ
# ============================================

def create_parser():
    parser = argparse.ArgumentParser(
        description="Управление пользователями и ACL для MQTT брокера (PostgreSQL + C plugin)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры использования:
  python manage_users_postgres.py list
  python manage_users_postgres.py add -u john
  python manage_users_postgres.py add -u admin -a
  python manage_users_postgres.py passwd -u john
  python manage_users_postgres.py del -u john
  python manage_users_postgres.py add-acl -u john -t "sensors/#" -r 1
  python manage_users_postgres.py add-acl -u john -t "actuators/light/set" -r 2
  python manage_users_postgres.py list-acls
  python manage_users_postgres.py list-acls -u john
  python manage_users_postgres.py del-acl -a 5
  python manage_users_postgres.py check
  python manage_users_postgres.py test-hash -p "mypassword"
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Команды')
    
    # Команда list (список пользователей)
    subparsers.add_parser('list', help='Показать список всех пользователей')
    
    # Команда add (добавление пользователя)
    parser_add = subparsers.add_parser('add', help='Добавить нового пользователя')
    parser_add.add_argument('-u', '--username', required=True, help='Имя пользователя')
    parser_add.add_argument('-a', '--admin', action='store_true', help='Сделать пользователя администратором (суперпользователем)')
    
    # Команда del (удаление пользователя)
    parser_del = subparsers.add_parser('del', help='Удалить пользователя')
    parser_del.add_argument('-u', '--username', required=True, help='Имя пользователя')
    
    # Команда passwd (изменение пароля)
    parser_passwd = subparsers.add_parser('passwd', help='Изменить пароль пользователя')
    parser_passwd.add_argument('-u', '--username', required=True, help='Имя пользователя')
    
    # Команда show (информация о пользователе)
    parser_show = subparsers.add_parser('show', help='Показать информацию о пользователе')
    parser_show.add_argument('-u', '--username', required=True, help='Имя пользователя')
    
    # Команда add-acl (добавление ACL)
    parser_add_acl = subparsers.add_parser('add-acl', help='Добавить правило ACL')
    parser_add_acl.add_argument('-u', '--username', required=True, help='Имя пользователя')
    parser_add_acl.add_argument('-t', '--topic', required=True, help='Топик (можно использовать + и #)')
    parser_add_acl.add_argument('-r', '--rw', type=int, required=True, choices=[1, 2, 3], 
                               help='Права доступа: 1=чтение, 2=запись, 3=чтение+запись')
    
    # Команда del-acl (удаление ACL)
    parser_del_acl = subparsers.add_parser('del-acl', help='Удалить правило ACL по ID')
    parser_del_acl.add_argument('-a', '--acl-id', type=int, required=True, help='ID правила ACL')
    
    # Команда list-acls (список ACL)
    parser_list_acls = subparsers.add_parser('list-acls', help='Показать список ACL правил')
    parser_list_acls.add_argument('-u', '--username', help='Фильтр по имени пользователя')
    
    # Команда check (проверка подключения)
    subparsers.add_parser('check', help='Проверить подключение к базе данных')
    
    # Команда test-hash (тестирование хеширования)
    parser_test = subparsers.add_parser('test-hash', help='Протестировать генерацию хеша пароля')
    parser_test.add_argument('-p', '--password', required=True, help='Пароль для тестирования')
    
    return parser

# ============================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================

def main():
    parser = create_parser()
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Выполнение команд
    if args.command == 'list':
        list_users()
    
    elif args.command == 'add':
        add_user(args.username, args.admin)
    
    elif args.command == 'del':
        delete_user(args.username)
    
    elif args.command == 'passwd':
        change_password(args.username)
    
    elif args.command == 'show':
        show_user_info(args.username)
    
    elif args.command == 'add-acl':
        add_acl(args.username, args.topic, args.rw)
    
    elif args.command == 'del-acl':
        delete_acl(args.acl_id)
    
    elif args.command == 'list-acls':
        list_acls(args.username)
    
    elif args.command == 'check':
        check_connection()
    
    elif args.command == 'test-hash':
        test_password_hash(args.password)
    
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
    