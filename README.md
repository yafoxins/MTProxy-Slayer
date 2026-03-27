# MTProxy + FakeTLS (Anti-DPI Ready)

## 🇷🇺 Русская версия

Готовый скрипт для установки Telegram MTProxy с поддержкой FakeTLS.

### Возможности

-   FakeTLS (ee secret)
-   Автообновление каждые 4 часа
-   Исправление kernel.pid_max
-   Systemd сервис

### Установка

``` bash
chmod +x mtproxy-install.sh
sudo bash mtproxy-install.sh
```

### FakeTLS

Формат:

    ee + SECRET + HEX(domain)

Пример:

    ee12a47d253fb8dca2814479a60a7446b5766b2e636f6d

### Домены

-   vk.com
-   vk.ru
-   petrovich.ru
-   yandex.ru
-   google.com

Требования: - TLS 1.3 - Порт 443 - Доступность из РФ

### Проверка

``` bash
systemctl status mtproxy
journalctl -u mtproxy -n 100 --no-pager
```

------------------------------------------------------------------------

## 🇬🇧 English Version

Ready-to-use MTProxy installer with FakeTLS support.

### Features

-   FakeTLS (ee secret)
-   Auto refresh every 4 hours
-   kernel.pid_max fix
-   Systemd service

### Install

``` bash
chmod +x mtproxy-install.sh
sudo bash mtproxy-install.sh
```

### FakeTLS format

    ee + SECRET + HEX(domain)

### Example

    ee12a47d253fb8dca2814479a60a7446b5766b2e636f6d

### Domains

-   vk.com
-   vk.ru
-   petrovich.ru
-   yandex.ru
-   google.com

Requirements: - TLS 1.3 support - Port 443 - Accessible from your region

### Check

``` bash
systemctl status mtproxy
journalctl -u mtproxy -n 100 --no-pager
```

------------------------------------------------------------------------

## Author

Yafoxin Dev\
https://t.me/yafoxindev
