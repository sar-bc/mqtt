#!/usr/bin/env python3
"""
MQTT User Management Script for SQLite
Использование: ./manage_users_sqlite.py [команда] [опции]
"""

import sqlite3
import hashlib
import os
import argparse
import getpass
from datetime import datetime
import sys

DB_PATH = "/mosquitto/config/mqtt_users.db"
CONTAINER_NAME = "mqtt_cont"

class MQTTUserManager:
    def __init__(self, db_path=DB_PATH):
        self.db_path = db_path
        
    def connect(self):
        """Подключение к базе данных"""
        try:
            # Пробуем подключиться через контейнер или локально
            if os.path.exists(self.db_path):
                conn = sqlite3.connect(self.db_path)
            else:
                # Если файла нет локально, пробуем через docker
                import subprocess
                result = subprocess.run(
                    ["docker", "exec", "-i", CONTAINER_NAME, "cat", self.db_path],
                    capture_output=True,
                    text=True
                )
                if result.returncode != 0:
                    raise Exception("Cannot access database")
                # Создаем временную копию
                with open("/tmp/mqtt_users.db", "w") as f:
                    f.write(result.stdout)
                conn = sqlite3.connect("/tmp/mqtt_users.db")
            return conn
        except Exception as e:
            print(f"❌ Cannot connect to database: {e}")
            sys.exit(1)

    def init_db(self):
        """Инициализация структуры базы данных"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Создаем таблицы
        cursor.executescript("""
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                password TEXT NOT NULL,
                superuser INTEGER DEFAULT 0,
                enabled INTEGER DEFAULT 1,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_modified DATETIME DEFAULT CURRENT_TIMESTAMP
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

            CREATE INDEX IF NOT EXISTS idx_acls_username ON acls(username);
            CREATE INDEX IF NOT EXISTS idx_acls_topic ON acls(topic);
        """)
        
        conn.commit()
        conn.close()
        print("✅ Database initialized successfully")

    def generate_password_hash(self, password):
        """Генерация хеша пароля (PBKDF2)"""
        salt = os.urandom(32).hex()
        iterations = 100000
        hash_bytes = hashlib.pbkdf2_hmac(
            'sha256',
            password.encode('utf-8'),
            salt.encode('utf-8'),
            iterations
        )
        hash_hex = hash_bytes.hex()
        return f"PBKDF2$sha256${iterations}${salt}${hash_hex}"

    def add_user(self, username, password, is_superuser=False):
        """Добавление нового пользователя"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Проверяем существование
        cursor.execute("SELECT username FROM users WHERE username = ?", (username,))
        if cursor.fetchone():
            print(f"❌ User '{username}' already exists")
            conn.close()
            return False
        
        # Генерируем хеш
        password_hash = self.generate_password_hash(password)
        super_val = 1 if is_superuser else 0
        
        cursor.execute(
            "INSERT INTO users (username, password, superuser) VALUES (?, ?, ?)",
            (username, password_hash, super_val)
        )
        conn.commit()
        conn.close()
        print(f"✅ User '{username}' created successfully")
        return True

    def delete_user(self, username):
        """Удаление пользователя"""
        conn = self.connect()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM users WHERE username = ?", (username,))
        deleted = cursor.rowcount
        conn.commit()
        conn.close()
        
        if deleted > 0:
            print(f"✅ User '{username}' deleted")
        else:
            print(f"❌ User '{username}' not found")

    def list_users(self):
        """Список всех пользователей"""
        conn = self.connect()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT username, superuser, enabled, created_at,
                   (SELECT COUNT(*) FROM acls WHERE acls.username = users.username) as acl_count
            FROM users
            ORDER BY username
        """)
        users = cursor.fetchall()
        conn.close()
        
        if not users:
            print("📭 No users found")
            return
        
        print("\n" + "="*80)
        print(f"{'Username':<15} {'Type':<8} {'Status':<8} {'ACLs':<5} Created")
        print("-"*80)
        for user in users:
            user_type = "👑 SUPER" if user[1] else "👤 user"
            status = "✅ active" if user[2] else "❌ disabled"
            created = user[3][:16] if user[3] else "unknown"
            print(f"{user[0]:<15} {user_type:<8} {status:<8} {user[4]:<5} {created}")
        print("="*80 + "\n")

    def change_password(self, username, new_password):
        """Смена пароля"""
        conn = self.connect()
        cursor = conn.cursor()
        
        cursor.execute("SELECT username FROM users WHERE username = ?", (username,))
        if not cursor.fetchone():
            print(f"❌ User '{username}' not found")
            conn.close()
            return False
        
        password_hash = self.generate_password_hash(new_password)
        cursor.execute(
            "UPDATE users SET password = ?, last_modified = CURRENT_TIMESTAMP WHERE username = ?",
            (password_hash, username)
        )
        conn.commit()
        conn.close()
        print(f"✅ Password changed for '{username}'")
        return True

    def toggle_user(self, username, enable=True):
        """Включение/отключение пользователя"""
        conn = self.connect()
        cursor = conn.cursor()
        
        status = 1 if enable else 0
        cursor.execute(
            "UPDATE users SET enabled = ?, last_modified = CURRENT_TIMESTAMP WHERE username = ?",
            (status, username)
        )
        if cursor.rowcount > 0:
            conn.commit()
            state = "enabled" if enable else "disabled"
            print(f"✅ User '{username}' {state}")
        else:
            print(f"❌ User '{username}' not found")
        conn.close()

    def add_acl(self, username, topic, rw=1):
        """Добавление правила доступа"""
        conn = self.connect()
        cursor = conn.cursor()
        
        # Проверяем существование пользователя
        cursor.execute("SELECT username FROM users WHERE username = ?", (username,))
        if not cursor.fetchone():
            print(f"❌ User '{username}' not found")
            conn.close()
            return False
        
        # Проверяем rw
        if rw not in [1, 2, 3]:
            rw = 1
        
        try:
            cursor.execute(
                "INSERT INTO acls (username, topic, rw) VALUES (?, ?, ?)",
                (username, topic, rw)
            )
            conn.commit()
            rw_desc = {1: "read", 2: "write", 3: "read/write"}[rw]
            print(f"✅ Added ACL: {username} can {rw_desc} on '{topic}'")
        except sqlite3.IntegrityError:
            print(f"❌ ACL for '{username}' on '{topic}' already exists")
            return False
        finally:
            conn.close()
        return True

    def remove_acl(self, username, topic=None):
        """Удаление правил доступа"""
        conn = self.connect()
        cursor = conn.cursor()
        
        if topic:
            cursor.execute(
                "DELETE FROM acls WHERE username = ? AND topic = ?",
                (username, topic)
            )
            removed = cursor.rowcount
            conn.commit()
            if removed > 0:
                print(f"✅ Removed ACL for {username} on '{topic}'")
            else:
                print(f"❌ ACL not found")
        else:
            cursor.execute("DELETE FROM acls WHERE username = ?", (username,))
            removed = cursor.rowcount
            conn.commit()
            print(f"✅ Removed all {removed} ACLs for '{username}'")
        conn.close()

    def list_acls(self, username=None):
        """Список правил доступа"""
        conn = self.connect()
        cursor = conn.cursor()
        
        if username:
            cursor.execute("""
                SELECT a.username, a.topic, a.rw, a.created_at
                FROM acls a
                WHERE a.username = ?
                ORDER BY a.topic
            """, (username,))
        else:
            cursor.execute("""
                SELECT a.username, a.topic, a.rw, a.created_at
                FROM acls a
                JOIN users u ON a.username = u.username
                ORDER BY a.username, a.topic
            """)
        
        acls = cursor.fetchall()
        conn.close()
        
        if not acls:
            print("📭 No ACLs found")
            return
        
        print("\n" + "="*80)
        print(f"{'Username':<15} {'Topic':<30} {'Access':<10} Created")
        print("-"*80)
        for acl in acls:
            rw_icon = {1: "📖 read", 2: "✏️ write", 3: "📝 read/write"}[acl[2]]
            created = acl[3][:16] if acl[3] else ""
            print(f"{acl[0]:<15} {acl[1]:<30} {rw_icon:<10} {created}")
        print("="*80 + "\n")

    def backup_db(self, backup_path):
        """Бэкап базы данных"""
        import shutil
        import subprocess
        
        try:
            if os.path.exists(self.db_path):
                shutil.copy2(self.db_path, backup_path)
            else:
                subprocess.run(
                    ["docker", "cp", f"{CONTAINER_NAME}:{self.db_path}", backup_path],
                    check=True
                )
            print(f"✅ Database backed up to {backup_path}")
        except Exception as e:
            print(f"❌ Backup failed: {e}")

def main():
    parser = argparse.ArgumentParser(description='MQTT User Management for SQLite')
    parser.add_argument('action', choices=[
        'init', 'add', 'delete', 'list', 'passwd', 
        'enable', 'disable', 'add-acl', 'rm-acl', 'list-acls', 'backup'
    ], help='Action to perform')
    
    parser.add_argument('--username', '-u', help='Username')
    parser.add_argument('--password', '-p', help='Password (if not provided, will prompt)')
    parser.add_argument('--superuser', '-s', action='store_true', help='Make user superuser')
    parser.add_argument('--topic', '-t', help='Topic pattern for ACL')
    parser.add_argument('--rw', '-r', type=int, choices=[1,2,3], default=1, 
                       help='Access level: 1=read, 2=write, 3=read/write')
    parser.add_argument('--backup-file', help='Backup file path')
    
    args = parser.parse_args()
    
    manager = MQTTUserManager()
    
    if args.action == 'init':
        manager.init_db()
    
    elif args.action == 'add':
        if not args.username:
            print("❌ --username required")
            return
        password = args.password
        if not password:
            password = getpass.getpass("Password: ")
            confirm = getpass.getpass("Confirm password: ")
            if password != confirm:
                print("❌ Passwords don't match")
                return
        manager.add_user(args.username, password, args.superuser)
    
    elif args.action == 'delete':
        if not args.username:
            print("❌ --username required")
            return
        confirm = input(f"Delete user '{args.username}'? (y/N): ")
        if confirm.lower() == 'y':
            manager.delete_user(args.username)
    
    elif args.action == 'list':
        manager.list_users()
    
    elif args.action == 'passwd':
        if not args.username:
            print("❌ --username required")
            return
        password = args.password
        if not password:
            password = getpass.getpass("New password: ")
            confirm = getpass.getpass("Confirm password: ")
            if password != confirm:
                print("❌ Passwords don't match")
                return
        manager.change_password(args.username, password)
    
    elif args.action == 'enable':
        if not args.username:
            print("❌ --username required")
            return
        manager.toggle_user(args.username, enable=True)
    
    elif args.action == 'disable':
        if not args.username:
            print("❌ --username required")
            return
        manager.toggle_user(args.username, enable=False)
    
    elif args.action == 'add-acl':
        if not args.username or not args.topic:
            print("❌ --username and --topic required")
            return
        manager.add_acl(args.username, args.topic, args.rw)
    
    elif args.action == 'rm-acl':
        if not args.username:
            print("❌ --username required")
            return
        manager.remove_acl(args.username, args.topic)
    
    elif args.action == 'list-acls':
        manager.list_acls(args.username)
    
    elif args.action == 'backup':
        backup_file = args.backup_file or f"mqtt_users_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        manager.backup_db(backup_file)

if __name__ == "__main__":
    main()
    