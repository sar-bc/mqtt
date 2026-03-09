#!/usr/bin/env python3
"""
MQTT User Management for PostgreSQL
Использование: ./manage_users_postgres.py [команда] [опции]

Команды:
  init                      - инициализация базы данных
  add -u USERNAME [-p] [-a] - добавить пользователя
  list                      - список пользователей
  passwd -u USERNAME [-p]   - сменить пароль
  enable -u USERNAME        - включить пользователя
  disable -u USERNAME       - отключить пользователя
  delete -u USERNAME        - удалить пользователя
  add-acl -u USERNAME -t TOPIC [-r RW] - добавить правило доступа
  list-acls [-u USERNAME]   - список правил доступа
"""

import psycopg2
import bcrypt
import argparse
import getpass
from datetime import datetime
import sys
import os

# Конфигурация подключения к PostgreSQL
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'mqtt_auth',
    'user': 'sar-bc',
    'password': 'Vik159753'
}

class MQTTUserManager:
    def __init__(self, config=DB_CONFIG):
        self.config = config
        
    def connect(self):
        """Подключение к PostgreSQL"""
        try:
            conn = psycopg2.connect(**self.config)
            conn.autocommit = False
            return conn
        except Exception as e:
            print(f"❌ Ошибка подключения к PostgreSQL: {e}")
            print("\nПроверьте:")
            print("  - Запущен ли контейнер: docker ps | grep postgres")
            print("  - Правильность пароля в DB_CONFIG")
            print("  - Логи: docker logs mqtt_postgres")
            sys.exit(1)
    
    def init_db(self):
        """Инициализация базы данных"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            # Создаем таблицу пользователей
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(255) UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    is_admin BOOLEAN DEFAULT false,
                    enabled BOOLEAN DEFAULT true,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Создаем таблицу ACL
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS acls (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(255) NOT NULL REFERENCES users(username) ON DELETE CASCADE,
                    topic VARCHAR(255) NOT NULL,
                    rw INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(username, topic)
                )
            """)
            
            # Создаем индексы
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_acls_username ON acls(username)")
            
            conn.commit()
            print("✅ База данных успешно инициализирована")
            
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка инициализации: {e}")
        finally:
            cursor.close()
            conn.close()
    
    def hash_password(self, password):
        """Генерация bcrypt хеша"""
        salt = bcrypt.gensalt(rounds=12)
        return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
    
    def add_user(self, username, password, is_admin=False):
        """Добавление пользователя"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            # Проверяем существование
            cursor.execute(
                "SELECT username FROM users WHERE username = %s",
                (username,)
            )
            if cursor.fetchone():
                print(f"❌ Пользователь {username} уже существует")
                return False
            
            # Хешируем пароль
            password_hash = self.hash_password(password)
            
            # Добавляем пользователя
            cursor.execute(
                "INSERT INTO users (username, password_hash, is_admin) VALUES (%s, %s, %s)",
                (username, password_hash, is_admin)
            )
            conn.commit()
            print(f"✅ Пользователь {username} создан")
            return True
            
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def list_users(self):
        """Список пользователей"""
        conn = self.connect()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT username, is_admin, enabled, 
                   TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') as created
            FROM users
            ORDER BY username
        """)
        users = cursor.fetchall()
        cursor.close()
        conn.close()
        
        if not users:
            print("📭 Нет пользователей")
            return
        
        print("\n" + "="*80)
        print(f"{'Username':<20} {'Type':<10} {'Status':<10} Created")
        print("-"*80)
        for user in users:
            user_type = "👑 ADMIN" if user[1] else "👤 user"
            status = "✅ active" if user[2] else "❌ disabled"
            print(f"{user[0]:<20} {user_type:<10} {status:<10} {user[3]}")
        print("="*80 + "\n")
    
    def change_password(self, username, new_password):
        """Смена пароля"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            # Проверяем существование
            cursor.execute(
                "SELECT username FROM users WHERE username = %s",
                (username,)
            )
            if not cursor.fetchone():
                print(f"❌ Пользователь {username} не найден")
                return False
            
            password_hash = self.hash_password(new_password)
            cursor.execute(
                "UPDATE users SET password_hash = %s WHERE username = %s",
                (password_hash, username)
            )
            conn.commit()
            print(f"✅ Пароль изменен для {username}")
            return True
            
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def toggle_user(self, username, enable=True):
        """Включение/отключение пользователя"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            cursor.execute(
                "UPDATE users SET enabled = %s WHERE username = %s",
                (enable, username)
            )
            if cursor.rowcount > 0:
                conn.commit()
                status = "включен" if enable else "отключен"
                print(f"✅ Пользователь {username} {status}")
            else:
                print(f"❌ Пользователь {username} не найден")
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка: {e}")
        finally:
            cursor.close()
            conn.close()
    
    def delete_user(self, username):
        """Удаление пользователя"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            cursor.execute("DELETE FROM users WHERE username = %s", (username,))
            deleted = cursor.rowcount
            conn.commit()
            
            if deleted > 0:
                print(f"✅ Пользователь {username} удален")
            else:
                print(f"❌ Пользователь {username} не найден")
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка: {e}")
        finally:
            cursor.close()
            conn.close()
    
    def add_acl(self, username, topic, rw=1):
        """Добавление правила доступа"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            # Проверяем существование пользователя
            cursor.execute(
                "SELECT username FROM users WHERE username = %s",
                (username,)
            )
            if not cursor.fetchone():
                print(f"❌ Пользователь {username} не найден")
                return False
            
            # Добавляем ACL
            cursor.execute(
                "INSERT INTO acls (username, topic, rw) VALUES (%s, %s, %s)",
                (username, topic, rw)
            )
            conn.commit()
            
            rw_desc = {1: "чтение", 2: "запись", 3: "чтение/запись"}[rw]
            print(f"✅ Добавлено: {username} может {rw_desc} на '{topic}'")
            return True
            
        except psycopg2.IntegrityError:
            conn.rollback()
            print(f"❌ Правило для {username} на '{topic}' уже существует")
            return False
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка: {e}")
            return False
        finally:
            cursor.close()
            conn.close()
    
    def remove_acl(self, username, topic=None):
        """Удаление правил доступа"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            if topic:
                cursor.execute(
                    "DELETE FROM acls WHERE username = %s AND topic = %s",
                    (username, topic)
                )
                deleted = cursor.rowcount
                if deleted > 0:
                    print(f"✅ Удалено правило для {username} на '{topic}'")
                else:
                    print(f"❌ Правило не найдено")
            else:
                cursor.execute(
                    "DELETE FROM acls WHERE username = %s",
                    (username,)
                )
                deleted = cursor.rowcount
                print(f"✅ Удалено {deleted} правил для {username}")
            
            conn.commit()
            
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка: {e}")
        finally:
            cursor.close()
            conn.close()
    
    def list_acls(self, username=None):
        """Список правил доступа"""
        conn = self.connect()
        cursor = conn.cursor()
        
        if username:
            cursor.execute("""
                SELECT username, topic, 
                       CASE rw 
                           WHEN 1 THEN 'read'
                           WHEN 2 THEN 'write'
                           ELSE 'readwrite'
                       END as access,
                       TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') as created
                FROM acls
                WHERE username = %s
                ORDER BY topic
            """, (username,))
        else:
            cursor.execute("""
                SELECT username, topic, 
                       CASE rw 
                           WHEN 1 THEN 'read'
                           WHEN 2 THEN 'write'
                           ELSE 'readwrite'
                       END as access,
                       TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') as created
                FROM acls
                ORDER BY username, topic
            """)
        
        acls = cursor.fetchall()
        cursor.close()
        conn.close()
        
        if not acls:
            print("📭 Нет правил доступа")
            return
        
        print("\n" + "="*90)
        print(f"{'Username':<20} {'Topic':<40} {'Access':<12} Created")
        print("-"*90)
        for acl in acls:
            rw_icon = "📖" if acl[2] == 'read' else "✏️" if acl[2] == 'write' else "📝"
            print(f"{acl[0]:<20} {acl[1]:<40} {rw_icon} {acl[2]:<10} {acl[3]}")
        print("="*90 + "\n")

def main():
    parser = argparse.ArgumentParser(description='Управление пользователями MQTT (PostgreSQL)')
    parser.add_argument('action', choices=[
        'init', 'add', 'list', 'passwd', 'enable', 'disable', 'delete', 
        'add-acl', 'rm-acl', 'list-acls'
    ])
    parser.add_argument('--username', '-u', help='Имя пользователя')
    parser.add_argument('--password', '-p', help='Пароль (если не указан, будет запрошен)')
    parser.add_argument('--admin', '-a', action='store_true', help='Сделать администратором')
    parser.add_argument('--topic', '-t', help='Топик для ACL (можно использовать + и #)')
    parser.add_argument('--rw', '-r', type=int, choices=[1,2,3], default=1,
                       help='Уровень доступа: 1=read, 2=write, 3=readwrite')
    
    args = parser.parse_args()
    
    manager = MQTTUserManager()
    
    if args.action == 'init':
        manager.init_db()
    
    elif args.action == 'add':
        if not args.username:
            print("❌ Требуется --username")
            return
        password = args.password
        if not password:
            password = getpass.getpass("Пароль: ")
            confirm = getpass.getpass("Подтвердите пароль: ")
            if password != confirm:
                print("❌ Пароли не совпадают")
                return
        manager.add_user(args.username, password, args.admin)
    
    elif args.action == 'list':
        manager.list_users()
    
    elif args.action == 'passwd':
        if not args.username:
            print("❌ Требуется --username")
            return
        password = args.password
        if not password:
            password = getpass.getpass("Новый пароль: ")
            confirm = getpass.getpass("Подтвердите пароль: ")
            if password != confirm:
                print("❌ Пароли не совпадают")
                return
        manager.change_password(args.username, password)
    
    elif args.action == 'enable':
        if not args.username:
            print("❌ Требуется --username")
            return
        manager.toggle_user(args.username, enable=True)
    
    elif args.action == 'disable':
        if not args.username:
            print("❌ Требуется --username")
            return
        manager.toggle_user(args.username, enable=False)
    
    elif args.action == 'delete':
        if not args.username:
            print("❌ Требуется --username")
            return
        confirm = input(f"Удалить пользователя {args.username}? (y/N): ")
        if confirm.lower() == 'y':
            manager.delete_user(args.username)
    
    elif args.action == 'add-acl':
        if not args.username or not args.topic:
            print("❌ Требуется --username и --topic")
            return
        manager.add_acl(args.username, args.topic, args.rw)
    
    elif args.action == 'rm-acl':
        if not args.username:
            print("❌ Требуется --username")
            return
        manager.remove_acl(args.username, args.topic)
    
    elif args.action == 'list-acls':
        manager.list_acls(args.username)

if __name__ == "__main__":
    main()
    