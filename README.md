## Управление пользователями MQTT

Все команды выполняются внутри контейнера `mqtt_cont`.

### Добавить нового пользователя
```bash
docker exec -it mqtt_cont mosquitto_passwd /mosquitto/config/passwords.txt новый_логин
```

### Удалить пользователя
```bash
docker exec -it mqtt_cont mosquitto_passwd -D /mosquitto/config/passwords.txt логин
```

### Сменить пароль существующему пользователю
```bash
docker exec -it mqtt_cont mosquitto_passwd /mosquitto/config/passwords.txt логин
```

### Применить изменения
```bash
docker exec -it mqtt_cont kill -HUP 1
```

### Просмотреть список пользователей
```bash
docker exec -it mqtt_cont cat /mosquitto/config/passwords.txt
```

### Проверить права на файл паролей
```bash
docker exec -it mqtt_cont ls -la /mosquitto/config/passwords.txt
```
