#!/usr/bin/env python3
"""
MQTT User Management for PostgreSQL
Использование: ./manage_users_postgres.py [команда] [опции]
"""

import psycopg2
import bcrypt
import argparse
import getpass
from datetime import datetime
import sys

DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'mqtt_auth',
    'user': 'mqtt_admin',
    'password': 'MqttSecurePass123!'
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
            print(f"❌ Cannot connect to PostgreSQL: {e}")
            sys.exit(1)
    
    def init_db(self):
        """Инициализация базы данных"""
        print("База данных инициализируется через init/init.sql")
        print("Убедитесь, что файл init.sql смонтирован в контейнер PostgreSQL")
    
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
        
        print("\n" + "="*70)
        print(f"{'Username':<20} {'Type':<10} {'Status':<10} Created")
        print("-"*70)
        for user in users:
            user_type = "👑 ADMIN" if user[1] else "👤 user"
            status = "✅ active" if user[2] else "❌ disabled"
            print(f"{user[0]:<20} {user_type:<10} {status:<10} {user[3]}")
        print("="*70 + "\n")
    
    def change_password(self, username, new_password):
        """Смена пароля"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            password_hash = self.hash_password(new_password)
            cursor.execute(
                "UPDATE users SET password_hash = %s WHERE username = %s",
                (password_hash, username)
            )
            if cursor.rowcount > 0:
                conn.commit()
                print(f"✅ Пароль изменен для {username}")
            else:
                print(f"❌ Пользователь {username} не найден")
        except Exception as e:
            conn.rollback()
            print(f"❌ Ошибка: {e}")
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
    
    def add_acl(self, username, topic, rw=1):
        """Добавление правила доступа"""
        conn = self.connect()
        cursor = conn.cursor()
        
        try:
            cursor.execute(
                "INSERT INTO acls (username, topic, rw) VALUES (%s, %s, %s)",
                (username, topic, rw)
            )
            conn.commit()
            rw_desc = {1: "read", 2: "write", 3: "read/write"}[rw]
            print(f"✅ Добавлено: {username} может {rw_desc} на '{topic}'")
        except psycopg2.IntegrityError:
            conn.rollback()
            print(f"❌ Правило для {username} на '{topic}' уже существует")
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
                SELECT username, topic, rw, 
                       TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') as created
                FROM acls
                WHERE username = %s
                ORDER BY topic
            """, (username,))
        else:
            cursor.execute("""
                SELECT username, topic, rw, 
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
        
        print("\n" + "="*80)
        print(f"{'Username':<20} {'Topic':<30} {'Access':<12} Created")
        print("-"*80)
        for acl in acls:
            rw_icon = {1: "📖 read", 2: "✏️ write", 3: "📝 read/write"}[acl[2]]
            print(f"{acl[0]:<20} {acl[1]:<30} {rw_icon:<12} {acl[3]}")
        print("="*80 + "\n")

def main():
    parser = argparse.ArgumentParser(description='Управление пользователями MQTT (PostgreSQL)')
    parser.add_argument('action', choices=[
        'add', 'list', 'passwd', 'enable', 'disable', 'add-acl', 'list-acls'
    ])
    parser.add_argument('--username', '-u', help='Имя пользователя')
    parser.add_argument('--password', '-p', help='Пароль')
    parser.add_argument('--admin', '-a', action='store_true', help='Сделать администратором')
    parser.add_argument('--topic', '-t', help='Топик для ACL')
    parser.add_argument('--rw', '-r', type=int, choices=[1,2,3], default=1,
                       help='Уровень доступа: 1=read, 2=write, 3=read/write')
    
    args = parser.parse_args()
    
    manager = MQTTUserManager()
    
    if args.action == 'add':
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
    
    elif args.action == 'add-acl':
        if not args.username or not args.topic:
            print("❌ Требуется --username и --topic")
            return
        manager.add_acl(args.username, args.topic, args.rw)
    
    elif args.action == 'list-acls':
        manager.list_acls(args.username)

if __name__ == "__main__":
    main()
    