# 🩸 MTProxy Slayer

    ███╗   ███╗████████╗██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗
    ████╗ ████║╚══██╔══╝██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
    ██╔████╔██║   ██║   ██████╔╝██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝ 
    ██║╚██╔╝██║   ██║   ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝  
    ██║ ╚═╝ ██║   ██║   ██║     ██║  ██║╚██████╔╝██╔╝ ██╗   ██║   
    ╚═╝     ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   

🔥 **MTProxy Slayer --- FakeTLS Anti-DPI Proxy**

------------------------------------------------------------------------

![Linux](https://img.shields.io/badge/Linux-supported-success?logo=linux)
![FakeTLS](https://img.shields.io/badge/FakeTLS-enabled-purple)
![MTProxy](https://img.shields.io/badge/MTProxy-official-blue)
![AutoUpdate](https://img.shields.io/badge/AutoUpdate-4h-green)
![Status](https://img.shields.io/badge/status-stable-brightgreen)
![Stars](https://img.shields.io/github/stars/yafoxins/MTProxy-Slayer?style=social)

------------------------------------------------------------------------

## 💀 What is this?

MTProxy Slayer --- это готовый скрипт, который:

✔ ставит MTProxy\
✔ включает FakeTLS\
✔ обходит DPI\
✔ сам обновляется\
✔ просто работает

------------------------------------------------------------------------

## ⚡ Install

``` bash
wget https://raw.githubusercontent.com/yafoxins/MTProxy-Slayer/main/mtproto.sh -O mtproxy.sh
chmod +x mtproxy.sh
sudo bash mtproxy.sh
```

------------------------------------------------------------------------

## 🩸 FakeTLS Explained

    Client → TLS handshake → looks like HTTPS
                 ↓
            MTProto inside
                 ↓
            Telegram servers

👉 DPI думает что это обычный HTTPS\
👉 На самом деле это Telegram

------------------------------------------------------------------------

## 🔐 Secret Format

    ee + SECRET + HEX(domain)

Example:

    ee12a47d253fb8dca2814479a60a7446b5766b2e636f6d

------------------------------------------------------------------------

## 🌐 Domains

  Domain         HEX
  -------------- --------------------------
  vk.com         766b2e636f6d
  vk.ru          766b2e7275
  petrovich.ru   706574726f766963682e7275

------------------------------------------------------------------------

## ⚙️ Change Domain

``` bash
FAKE_TLS_DOMAIN=yandex.ru sudo bash mtproxy.sh
```

------------------------------------------------------------------------

## 🔄 Auto Update

Каждые 4 часа:

``` bash
wget getProxySecret
wget getProxyConfig
systemctl restart mtproxy
```

💡 Это нужно потому что Telegram меняет маршруты

------------------------------------------------------------------------

## 📊 Stats

``` bash
curl http://127.0.0.1:8888/stats
```

------------------------------------------------------------------------

## 🧠 Kernel Fix

    kernel.pid_max = 32768

Иначе MTProxy падает 💀

------------------------------------------------------------------------

## 🧪 Troubleshooting

``` bash
journalctl -u mtproxy -n 100
```

------------------------------------------------------------------------

## 👑 Author

**Yafoxin Dev**\
https://t.me/yafoxindev

------------------------------------------------------------------------

## ⭐ Star this repo

Если помогло --- поставь ⭐

------------------------------------------------------------------------

🔥 **MTProxy Slayer --- because DPI deserves to die**
