#!/usr/bin/env python3
"""
MQTT User Management for MariaDB/MySQL
Использование: ./manage_users_mariadb.py [команда] [опции]
"""

import mysql.connector
import bcrypt
import argparse
import getpass
from datetime import datetime
import sys

DB_CONFIG = {
    'host': 'localhost',
    'port': 3306,
    'database': 'mqtt_auth',
    'user': 'mqtt_user',
    'password': 'MqttSecurePass123!'
}

class MQTTUserManager:
    def __init__(self, config=DB_CONFIG):
        self.config = config
        
    def connect(self):
        """Подключение к MariaDB"""
        try:
            conn = mysql.connector.connect(**self.config)
            conn.autocommit = False
            return conn
        except Exception as e:
            print(f"❌ Cannot connect to MariaDB: {e}")
            print("\nПроверьте:")
            print("  - Запущен ли контейнер: docker ps | grep mariadb")
            print("  - Правильность пароля в DB_CONFIG")
            print("  - Логи: docker logs mqtt_mariadb")
            sys.exit(1)
    
    def hash_password(self, password):
        """Генерация bcrypt хеша"""
        salt = bcrypt.gensalt(rounds=12)
        return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
    
    def init_db(self):
        """Инициализация базы данных (вызывается автоматически через init.sql)"""
        print("📁 База данных инициализируется через init/init.sql")
        print("Убедитесь, что файл init.sql смонтирован в контейнер MariaDB")
    
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
                   DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i') as created
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
            cursor.execute(
                "INSERT INTO acls (username, topic, rw) VALUES (%s, %s, %s)",
                (username, topic, rw)
            )
            conn.commit()
            rw_desc = {1: "read", 2: "write", 3: "read/write"}[rw]
            print(f"✅ Добавлено: {username} может {rw_desc} на '{topic}'")
        except mysql.connector.IntegrityError:
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
                SELECT username, topic, 
                       CASE rw WHEN 1 THEN 'read' WHEN 2 THEN 'write' ELSE 'read/write' END as access,
                       DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i') as created
                FROM acls
                WHERE username = %s
                ORDER BY topic
            """, (username,))
        else:
            cursor.execute("""
                SELECT username, topic, 
                       CASE rw WHEN 1 THEN 'read' WHEN 2 THEN 'write' ELSE 'read/write' END as access,
                       DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i') as created
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
            rw_icon = "📖" if acl[2] == 'read' else "✏️" if acl[2] == 'write' else "📝"
            print(f"{acl[0]:<20} {acl[1]:<30} {rw_icon} {acl[2]:<10} {acl[3]}")
        print("="*80 + "\n")

def main():
    parser = argparse.ArgumentParser(description='Управление пользователями MQTT (MariaDB)')
    parser.add_argument('action', choices=[
        'add', 'list', 'passwd', 'enable', 'disable', 'delete', 'add-acl', 'list-acls'
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
    
    elif args.action == 'list-acls':
        manager.list_acls(args.username)

if __name__ == "__main__":
    main()
    