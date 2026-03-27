<p align="center">
  <img src="https://raw.githubusercontent.com/yafoxins/MTProxy-Slayer/main/assets/banner.svg" alt="MTProxy Slayer banner" width="100%" />
</p>

<h1 align="center">MTProxy Slayer</h1>
<p align="center">
  <b>Production-ready MTProxy installer with FakeTLS, systemd timer refresh, and Linux compatibility fixes.</b><br/>
  <sub>Готовый установщик MTProxy с FakeTLS, автообновлением конфигов и фиксом совместимости Linux.</sub>
</p>

<p align="center">
  <a href="https://github.com/yafoxins/MTProxy-Slayer/stargazers"><img src="https://img.shields.io/github/stars/yafoxins/MTProxy-Slayer?style=for-the-badge&logo=github&label=Stars" alt="GitHub stars"></a>
  <a href="https://github.com/yafoxins/MTProxy-Slayer/network/members"><img src="https://img.shields.io/github/forks/yafoxins/MTProxy-Slayer?style=for-the-badge&logo=github&label=Forks" alt="GitHub forks"></a>
  <a href="https://github.com/yafoxins/MTProxy-Slayer/issues"><img src="https://img.shields.io/github/issues/yafoxins/MTProxy-Slayer?style=for-the-badge&logo=github&label=Issues" alt="GitHub issues"></a>
  <a href="https://github.com/yafoxins/MTProxy-Slayer/commits/main"><img src="https://img.shields.io/github/last-commit/yafoxins/MTProxy-Slayer?style=for-the-badge&logo=github&label=Updated" alt="Last commit"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Linux-supported-0f766e?style=flat-square&logo=linux&logoColor=white" alt="Linux supported">
  <img src="https://img.shields.io/badge/MTProxy-official%20build-2563eb?style=flat-square" alt="Official MTProxy build">
  <img src="https://img.shields.io/badge/FakeTLS-enabled-7c3aed?style=flat-square" alt="FakeTLS enabled">
  <img src="https://img.shields.io/badge/systemd-auto--refresh%204h-16a34a?style=flat-square" alt="systemd timer">
  <img src="https://img.shields.io/badge/Port-443-e11d48?style=flat-square" alt="Port 443">
  <img src="https://img.shields.io/badge/Shell-Bash-f59e0b?style=flat-square&logo=gnu-bash&logoColor=white" alt="Shell">
</p>

---

## Table of contents / Содержание

- [Why this project? / Зачем проект?](#why-this-project--зачем-проект)
- [Key features / Что умеет](#key-features--что-умеет)
- [How FakeTLS works / Как работает FakeTLS](#how-faketls-works--как-работает-faketls)
- [Quick start / Быстрый старт](#quick-start--быстрый-старт)
- [Configuration / Параметры](#configuration--параметры)
- [FakeTLS domains / Домены FakeTLS](#faketls-domains--домены-faketls)
- [Auto-refresh / Автообновление](#auto-refresh--автообновление)
- [Domain check before use / Проверка домена перед использованием](#domain-check-before-use--проверка-домена-перед-использованием)
- [Service layout / Что создаёт скрипт](#service-layout--что-создаёт-скрипт)
- [Verification / Проверка](#verification--проверка)
- [Troubleshooting / Частые проблемы](#troubleshooting--частые-проблемы)
- [Roadmap](#roadmap)
- [Author](#author)

---

## Why this project? / Зачем проект?

**EN:**  
`MTProxy Slayer` is a practical installer for your own Telegram MTProxy server with **FakeTLS**, automatic refresh of Telegram proxy configuration, and a built-in workaround for the well-known `kernel.pid_max` issue that can crash MTProxy on some VPS setups.

**RU:**  
`MTProxy Slayer` — это практичный установщик собственного Telegram MTProxy-сервера с **FakeTLS**, автоматическим обновлением конфигов Telegram и встроенным обходом проблемы `kernel.pid_max`, из-за которой MTProxy может падать на некоторых VPS.

> This repository is built around the current installation script used in this project.  
> Основа README и описания параметров соответствует текущему установочному скрипту проекта.

---

## Key features / Что умеет

<table>
  <tr>
    <td width="33%">
      <h3>🔐 FakeTLS</h3>
      <p><b>EN:</b> Uses <code>ee</code> secrets and a real TLS 1.3 domain mask.<br/>
      <b>RU:</b> Использует <code>ee</code>-секрет и маскировку под реальный TLS 1.3 домен.</p>
    </td>
    <td width="33%">
      <h3>🔄 Auto refresh</h3>
      <p><b>EN:</b> Refreshes <code>proxy-secret</code> and <code>proxy-multi.conf</code> every 4 hours using <code>systemd</code> timer.<br/>
      <b>RU:</b> Обновляет <code>proxy-secret</code> и <code>proxy-multi.conf</code> каждые 4 часа через <code>systemd</code> timer.</p>
    </td>
    <td width="33%">
      <h3>🛠 Linux fix</h3>
      <p><b>EN:</b> Applies a safe <code>kernel.pid_max</code> value for MTProxy compatibility.<br/>
      <b>RU:</b> Применяет безопасное значение <code>kernel.pid_max</code> для совместимости с MTProxy.</p>
    </td>
  </tr>
</table>

### At a glance / Коротко

- installs the **official MTProxy source** and builds it locally  
- configures a **systemd service** for the proxy  
- configures a **systemd timer** for periodic refresh  
- generates a **FakeTLS connection link** in both `tg://` and `https://t.me/proxy` formats  
- exposes a local **stats endpoint** on `127.0.0.1:8888` by default  

---

## How FakeTLS works / Как работает FakeTLS

### The short version / Коротко

**EN:** FakeTLS makes MTProxy traffic resemble a normal HTTPS connection. DPI sees a TLS 1.3-looking handshake, while Telegram traffic is carried inside that session format.  
**RU:** FakeTLS делает трафик MTProxy похожим на обычное HTTPS-соединение. DPI видит handshake, похожий на TLS 1.3, а внутри этого формата проходит Telegram-трафик.

```mermaid
flowchart LR
    A[Telegram client] --> B[FakeTLS handshake]
    B --> C[DPI sees HTTPS-like traffic]
    C --> D[MTProxy server]
    D --> E[Telegram network]
```

### FakeTLS secret format / Формат секрета

```text
ee + SECRET + HEX(domain)
```

**Example / Пример**

```text
ee12a47d253fb8dca2814479a60a7446b5766b2e636f6d
```

Breakdown:

- `ee` → enables **FakeTLS** mode  
- `12a47d253fb8dca2814479a60a7446` → random 16-byte secret in hex  
- `766b2e636f6d` → `vk.com` encoded as hex  

### FakeTLS vs regular MTProxy / Отличие от обычного MTProxy

| Mode | Prefix | Meaning |
|---|---|---|
| Regular MTProxy | `dd` | random padding, no TLS camouflage |
| FakeTLS | `ee` | TLS-like camouflage using a selected domain |

### Why the domain matters / Почему домен важен

**EN:** The selected domain is used as a TLS camouflage target. In practice, it should support **TLS 1.3**, respond correctly on port **443**, and be reachable from the client network where you plan to use the proxy.  
**RU:** Выбранный домен используется как цель маскировки под TLS. На практике он должен поддерживать **TLS 1.3**, корректно работать на порту **443** и быть доступным из той сети, где ты собираешься использовать прокси.

> Note: when people casually say “TLS 3”, they almost always mean **TLS 1.3**.  
> Примечание: когда говорят “TLS 3”, обычно имеют в виду именно **TLS 1.3**.

---

## Quick start / Быстрый старт

### 1) Download the installer / Скачай установщик

```bash
wget https://raw.githubusercontent.com/yafoxins/MTProxy-Slayer/main/mtproto.sh -O mtproxy.sh
chmod +x mtproxy.sh
```

### 2) Run it as root / Запусти от root

```bash
sudo bash mtproxy.sh
```

### 3) Copy the generated proxy link / Скопируй готовую ссылку

After installation, the script prints:

- `tg://proxy?server=...`
- `https://t.me/proxy?server=...`

---

## Configuration / Параметры

The installer supports environment variables.  
Установщик поддерживает переменные окружения.

### Available parameters / Доступные параметры

| Variable | Default | Description |
|---|---:|---|
| `PORT` | `443` | MTProxy listen port / Порт MTProxy |
| `STATS_PORT` | `8888` | local stats port / локальный порт статистики |
| `FAKE_TLS_DOMAIN` | `vk.com` | domain used for FakeTLS mask / домен для маскировки FakeTLS |

### Examples / Примеры

#### Change FakeTLS domain / Сменить домен FakeTLS

```bash
FAKE_TLS_DOMAIN=vk.ru sudo bash mtproxy.sh
```

```bash
FAKE_TLS_DOMAIN=petrovich.ru sudo bash mtproxy.sh
```

#### Change service port / Сменить порт сервиса

```bash
PORT=8443 sudo bash mtproxy.sh
```

#### Change stats port / Сменить порт статистики

```bash
STATS_PORT=9000 sudo bash mtproxy.sh
```

#### Combine parameters / Комбинировать параметры

```bash
FAKE_TLS_DOMAIN=yandex.ru PORT=443 STATS_PORT=8888 sudo bash mtproxy.sh
```

---

## FakeTLS domains / Домены FakeTLS

### Ready examples / Готовые примеры

| Domain | HEX | Notes |
|---|---|---|
| `vk.com` | `766b2e636f6d` | default in this script |
| `vk.ru` | `766b2e7275` | shorter RU domain |
| `petrovich.ru` | `706574726f766963682e7275` | requested example |
| `yandex.ru` | `79616e6465782e7275` | often practical for RU networks |
| `google.com` | `676f6f676c652e636f6d` | widely known public domain |

### Choosing a domain / Как выбирать домен

Good candidate checklist:

- supports **TLS 1.3**
- listens on **443**
- is reachable from the target client network
- is stable enough to be used repeatedly

Important note:

**EN:** There is no universal “best domain” for all networks. A domain that works great in one region or ISP can perform worse in another.  
**RU:** Нет универсально лучшего домена для всех сетей. Домен, который отлично работает у одного провайдера или региона, может работать хуже у другого.

---


## Domain check before use / Проверка домена перед использованием

### Important / Важно

**EN:**  
A normal `ping` test is **not enough** for FakeTLS. Many websites ignore ICMP or rate-limit it, while FakeTLS actually depends on **TCP/443 reachability** and a working **TLS 1.3 handshake**.

**RU:**  
Обычного `ping` **недостаточно** для FakeTLS. Многие сайты не отвечают на ICMP или режут его по rate-limit, а для FakeTLS реально важны **доступность TCP/443** и успешный **TLS 1.3 handshake**.

### Recommended check flow / Рекомендуемая проверка

#### 1) DNS resolution / Проверка DNS

```bash
DOMAIN=vk.com
getent ahostsv4 "$DOMAIN"
```

#### 2) Optional ICMP ping / Необязательный ping

```bash
ping -c 4 "$DOMAIN"
```

Use this only as a rough latency hint. A failed ping does **not** automatically mean the domain is bad for FakeTLS.  
Используй это только как грубую оценку задержки. Неудачный `ping` **не означает**, что домен плохой для FakeTLS.

#### 3) Check TCP port 443 / Проверка TCP-порта 443

```bash
nc -vz "$DOMAIN" 443
```

If `nc` is not installed:

```bash
timeout 5 bash -c "cat < /dev/null > /dev/tcp/$DOMAIN/443" && echo OK || echo FAIL
```

#### 4) Verify TLS 1.3 handshake / Проверка TLS 1.3

```bash
openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" -tls1_3 < /dev/null
```

A good result usually shows:
- successful certificate chain output
- negotiated TLS session
- no immediate handshake failure

Нормальный результат обычно показывает:
- успешный вывод цепочки сертификатов
- согласованную TLS-сессию
- отсутствие мгновенного падения handshake

#### 5) Measure real connect timings / Измерение реальных таймингов

```bash
curl -o /dev/null -sS \
  --connect-timeout 5 \
  -w "dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n" \
  "https://$DOMAIN/"
```

What matters most:
- lower `tcp`
- stable `tls`
- no frequent timeout spikes

Что важнее всего:
- низкий `tcp`
- стабильный `tls`
- отсутствие частых timeout'ов

### Quick all-in-one check / Быстрая комплексная проверка

```bash
DOMAIN=vk.com

echo "== DNS =="
getent ahostsv4 "$DOMAIN" || true
echo

echo "== ICMP ping =="
ping -c 4 "$DOMAIN" || true
echo

echo "== TCP 443 =="
nc -vz "$DOMAIN" 443 || true
echo

echo "== TLS 1.3 =="
openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" -tls1_3 < /dev/null 2>/dev/null | sed -n '1,20p'
echo

echo "== Timings =="
curl -o /dev/null -sS \
  --connect-timeout 5 \
  -w "dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n" \
  "https://$DOMAIN/" || true
```

### Best practice / Лучшая практика

**EN:**  
Test the domain from the **same network type** where the proxy will actually be used. A domain that looks fine from the server may behave differently from the client ISP or country.

**RU:**  
Проверяй домен из **того же типа сети**, где реально будет использоваться прокси. Домен, который хорошо выглядит с сервера, может вести себя иначе у клиентского провайдера или в другой стране.

### Practical domain selection advice / Практический совет по выбору

A domain is usually a good FakeTLS candidate if:

- TCP/443 connects fast
- TLS 1.3 works reliably
- `curl` timings are stable across multiple checks
- the domain is consistently reachable from the client network

Домен обычно подходит для FakeTLS, если:

- TCP/443 подключается быстро
- TLS 1.3 стабильно работает
- тайминги `curl` ровные в нескольких проверках
- домен стабильно доступен из клиентской сети

### Tiny helper script / Маленький helper-скрипт

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:?Usage: $0 domain}"

echo "Checking: $DOMAIN"
echo

echo "[1] DNS"
getent ahostsv4 "$DOMAIN" || true
echo

echo "[2] Ping"
ping -c 4 "$DOMAIN" || true
echo

echo "[3] TCP 443"
nc -vz "$DOMAIN" 443 || true
echo

echo "[4] TLS 1.3"
openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" -tls1_3 < /dev/null 2>/dev/null | sed -n '1,20p'
echo

echo "[5] Timings"
curl -o /dev/null -sS \
  --connect-timeout 5 \
  -w "dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n" \
  "https://$DOMAIN/" || true
```

## Auto-refresh / Автообновление

### What gets refreshed? / Что обновляется?

Every 4 hours, the timer runs a one-shot service that:

```bash
cd /opt/mtproxy && \
wget -4 -q https://core.telegram.org/getProxySecret -O proxy-secret && \
wget -4 -q https://core.telegram.org/getProxyConfig -O proxy-multi.conf && \
systemctl restart mtproxy
```

### Why is this useful? / Зачем это нужно?

**EN:**  
Telegram proxy metadata can change over time. Refreshing `proxy-secret` and `proxy-multi.conf` helps keep the server aligned with current Telegram proxy settings. The automatic restart applies fresh data without manual intervention.

**RU:**  
Метаданные Telegram-прокси со временем могут меняться. Обновление `proxy-secret` и `proxy-multi.conf` помогает держать сервер в актуальном состоянии относительно текущих настроек Telegram-прокси. Автоматический перезапуск применяет свежие данные без ручных действий.

### Timer behavior / Как работает timer

- starts **10 minutes after boot**
- repeats every **4 hours**
- survives reboots thanks to `Persistent=true`

---

## Service layout / Что создаёт скрипт

The installer creates:

```text
/opt/mtproxy/
├── mtproto-proxy
├── proxy-secret
├── proxy-multi.conf
└── user-secret

/etc/systemd/system/
├── mtproxy.service
├── mtproxy-refresh.service
└── mtproxy-refresh.timer

/etc/sysctl.d/
└── 99-mtproxy-pid.conf
```

### What each part does / Что делает каждая часть

- `mtproxy.service` → runs the actual MTProxy server  
- `mtproxy-refresh.service` → refreshes Telegram config files and restarts the service  
- `mtproxy-refresh.timer` → schedules refresh every 4 hours  
- `99-mtproxy-pid.conf` → forces a safe `kernel.pid_max` value for MTProxy compatibility  

---

## Verification / Проверка

### Service status / Статус сервиса

```bash
systemctl status mtproxy
```

### Recent logs / Последние логи

```bash
journalctl -u mtproxy -n 100 --no-pager
```

### Timer status / Статус таймера

```bash
systemctl status mtproxy-refresh.timer
systemctl list-timers --all | grep mtproxy-refresh
```

### Local stats / Локальная статистика

```bash
curl http://127.0.0.1:8888/stats
```

### Current pid_max / Текущее значение pid_max

```bash
cat /proc/sys/kernel/pid_max
```

---

## Troubleshooting / Частые проблемы

### MTProxy exits with PID assertion / Падает с ошибкой PID

**Symptom / Симптом:**  
MTProxy crashes with an assertion related to `common/pid.c`.

**Cause / Причина:**  
Some VPS templates use a `kernel.pid_max` value that is too large for MTProxy.

**Fix / Решение:**  
This project already applies:

```bash
kernel.pid_max = 32768
```

If needed, reapply manually:

```bash
cat >/etc/sysctl.d/99-mtproxy-pid.conf <<'EOF'
kernel.pid_max = 32768
EOF
sysctl --system
systemctl restart mtproxy
```

### Port already in use / Порт уже занят

```bash
ss -tulpn | grep :443
```

Change the port if needed:

```bash
PORT=8443 sudo bash mtproxy.sh
```

### FakeTLS domain behaves poorly / Домен работает плохо

Try another public TLS 1.3 domain:

```bash
FAKE_TLS_DOMAIN=vk.ru sudo bash mtproxy.sh
```

```bash
FAKE_TLS_DOMAIN=yandex.ru sudo bash mtproxy.sh
```

### Want to rebuild cleanly / Хочешь переставить с нуля

Just rerun the script as root; it stops previous units, recreates files, and deploys the new configuration.

---

## Roadmap

- [ ] optional domain auto-probing before install
- [ ] Docker deployment variant
- [ ] IPv6 checks
- [ ] optional firewall presets
- [ ] domain testing helper script

---

## Author

<p align="center">
  <img src="https://raw.githubusercontent.com/yafoxins/MTProxy-Slayer/main/assets/logo.svg" alt="MTProxy Slayer logo" width="120" />
</p>

<p align="center">
  <b>Yafoxin Dev</b><br/>
  Telegram: <a href="https://t.me/yafoxindev">t.me/yafoxindev</a>
</p>

---

## Star the project

If this repository saved your time, give it a ⭐ on GitHub.

Если этот репозиторий сэкономил тебе время — поставь ⭐ на GitHub.
