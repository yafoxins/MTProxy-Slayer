<p align="center">
  <img src="https://raw.githubusercontent.com/yafoxins/MTProxy-Slayer/main/assets/banner.svg" alt="MTProxy Slayer banner" width="100%" />
</p>

<h1 align="center">MTProxy Slayer</h1>
<p align="center">
  <b>Clean MTProxy + FakeTLS installer with domain quality probing, interactive port selection, systemd refresh and rich operational output.</b><br/>
  <sub>Аккуратный установщик MTProxy + FakeTLS с проверкой доменов, интерактивным выбором порта, systemd-обновлением и подробным итоговым выводом.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Bash-only-f59e0b?style=flat-square&logo=gnu-bash&logoColor=white" alt="Bash only">
  <img src="https://img.shields.io/badge/FakeTLS-TLS1.3-7c3aed?style=flat-square" alt="FakeTLS TLS 1.3">
  <img src="https://img.shields.io/badge/Auto-refresh-4h-16a34a?style=flat-square" alt="Refresh every 4h">
  <img src="https://img.shields.io/badge/Recommended%20port-443-e11d48?style=flat-square" alt="Recommended port 443">
</p>

---

## Table of contents / Оглавление

- [Overview / Обзор](#overview--обзор)
- [What is MTProxy and FakeTLS / Что такое MTProxy и FakeTLS](#what-is-mtproxy-and-faketls--что-такое-mtproxy-и-faketls)
- [How ee secret works / Как работает длинный ee-secret](#how-ee-secret-works--как-работает-длинный-ee-secret)
- [Why TLS 1.3 and not ping-only / Почему важен TLS-1.3, а ping недостаточен](#why-tls-13-and-not-ping-only--почему-важен-tls-13-а-ping-недостаточен)
- [Quick start / Быстрый старт](#quick-start--быстрый-старт)
- [Installer flow / Как проходит установка](#installer-flow--как-проходит-установка)
- [Configuration and env overrides / Параметры и env override](#configuration-and-env-overrides--параметры-и-env-override)
- [Domain auto-selection scoring / Логика auto-select scoring](#domain-auto-selection-scoring--логика-auto-select-scoring)
- [How to properly test a domain for FakeTLS / Как качественно проверить домен для FakeTLS](#how-to-properly-test-a-domain-for-faketls--как-качественно-проверить-домен-для-faketls)
- [Files and services / Файлы и сервисы](#files-and-services--файлы-и-сервисы)
- [Operations / Эксплуатация](#operations--эксплуатация)
- [Troubleshooting](#troubleshooting)
- [Author](#author)

---

## Overview / Обзор

**EN**

`MTProxy-Slayer` installs official MTProxy from source, enables FakeTLS mode, creates `systemd` service + timer refresh every 4 hours, applies `kernel.pid_max=32768` compatibility fix, and writes full proxy metadata into:

- `/opt/mtproxy/mtproxy-info.txt`
- `/opt/mtproxy/mtproxy-info.env`

**RU**

`MTProxy-Slayer` ставит официальный MTProxy из исходников, включает FakeTLS, создает `systemd`-сервис + таймер автообновления каждые 4 часа, применяет фикс `kernel.pid_max=32768` и сохраняет всю информацию о прокси в:

- `/opt/mtproxy/mtproxy-info.txt`
- `/opt/mtproxy/mtproxy-info.env`

---

## What is MTProxy and FakeTLS / Что такое MTProxy и FakeTLS

**EN**

- **MTProxy** is Telegram’s proxy protocol implementation.
- **FakeTLS** is MTProxy mode where traffic shape imitates TLS handshake/profile.
- It is configured by using an `ee` prefixed client secret containing both random secret and target domain in hex.

**RU**

- **MTProxy** — это прокси-протокол Telegram.
- **FakeTLS** — режим MTProxy, где трафик имитирует TLS-профиль.
- Настраивается через `ee`-секрет: внутри есть случайный secret и домен в hex.

---

## How ee secret works / Как работает длинный ee-secret

Format:

```text
ee + 16-byte-random-secret-hex + domain-hex
```

Example:

```text
ee12a47d253fb8dca2814479a60a7446766b2e636f6d
```

Where:

- `ee` — enables FakeTLS mode
- `12a47d...` — short secret (16 bytes, hex)
- `766b2e636f6d` — `vk.com` encoded to hex

---

## Why TLS 1.3 and not ping-only / Почему важен TLS-1.3, а ping недостаточен

**EN**

Ping is only an auxiliary signal. Some domains block ICMP but still work perfectly for HTTPS/TLS. For FakeTLS quality, the critical checks are:

1. DNS resolution
2. TCP connection to `:443`
3. Stable TLS 1.3 handshake
4. Timing quality (`curl` connect + appconnect)

**RU**

`ping` — лишь вспомогательный сигнал. Многие домены режут ICMP, но отлично работают по HTTPS/TLS. Для FakeTLS ключевые проверки:

1. DNS резолв
2. TCP подключение к `:443`
3. Стабильный TLS 1.3 handshake
4. Качество таймингов (`curl` connect + appconnect)

---

## Quick start / Быстрый старт

```bash
wget https://raw.githubusercontent.com/yafoxins/MTProxy-Slayer/main/mtproto.sh -O mtproxy.sh
chmod +x mtproxy.sh
sudo bash mtproxy.sh
```

Installer asks interactively:

1. Domain mode
   - `1` manual SNI/domain
   - `2` auto-select best domain from seed list
2. Proxy port (**recommended: 443**)
3. Stats port (default `8888`)

---

## Installer flow / Как проходит установка

1. Beautiful interactive CLI with `info/warn/error/success`
2. Domain mode selection (manual vs auto)
3. Mandatory port selection and validation (`1..65535`, free port check)
4. Optional stats port confirmation
5. MTProxy rebuild from official source
6. Download `proxy-secret` and `proxy-multi.conf`
7. `systemd` units generation:
   - `mtproxy.service`
   - `mtproxy-refresh.service`
   - `mtproxy-refresh.timer`
8. Auto-refresh each 4 hours
9. Final output with:
   - `tg://proxy?...`
   - `https://t.me/proxy?...`
10. Info saved to `/opt/mtproxy/mtproxy-info.txt` and `.env`

---

## Configuration and env overrides / Параметры и env override

Supported env variables:

| Variable | Default | Notes |
|---|---:|---|
| `PORT` | `443` | Used as prefilled default in interactive prompt |
| `STATS_PORT` | `8888` | Default stats endpoint port |
| `FAKE_TLS_DOMAIN` | none | Used as suggested value in manual mode |

### Behavior details / Поведение

- `PORT` from env does **not** skip prompt; it pre-fills the default.
- Manual mode: `FAKE_TLS_DOMAIN` is used as default prompt value.
- Auto mode: `FAKE_TLS_DOMAIN` is intentionally ignored (installer selects best runtime candidate from VPS tests).
- Recommended proxy port is explicitly **443**.

### Examples

```bash
PORT=8443 sudo bash mtproxy.sh
```

```bash
STATS_PORT=9000 sudo bash mtproxy.sh
```

```bash
FAKE_TLS_DOMAIN=vk.com sudo bash mtproxy.sh
```

```bash
PORT=443 STATS_PORT=8888 FAKE_TLS_DOMAIN=google.com sudo bash mtproxy.sh
```

---

## Domain auto-selection scoring / Логика auto-select scoring

Seed candidates used by default:

- `yandex.ru`
- `vk.com`
- `vk.ru`
- `petrovich.ru`
- `google.com`
- `ozon.ru`
- `avito.ru`
- `mail.ru`
- `wildberries.ru`
- `gosuslugi.ru`

### Runtime validation pipeline

Each domain is tested **from the current VPS**, minimum 3 probes:

1. `check_dns` (must pass)
2. `check_tcp_443` (must pass)
3. `check_tls13` (must pass stably: at least 2/3 TLS checks)
4. `measure_domain_timings` via `curl --tlsv1.3` (median connect/appconnect)
5. `check_ping` as secondary signal

Domains failing TCP or unstable TLS 1.3 are excluded.

### Score model

Lower score is better:

```text
score = 0.45*tcp_ms + 0.45*tls_ms + 0.10*ping_ms
```

- TCP and TLS timings are primary criteria.
- Ping has lower weight and never acts as a hard gate.
- Installer prints full domain table with selected winner.

---

## How to properly test a domain for FakeTLS / Как качественно проверить домен для FakeTLS

> Ping is helpful, but not authoritative.

### 1) DNS

```bash
DOMAIN=vk.com
getent ahostsv4 "$DOMAIN"
```

### 2) TCP/443

```bash
timeout 5 bash -c "</dev/tcp/$DOMAIN/443" && echo "TCP OK" || echo "TCP FAIL"
```

### 3) TLS 1.3 handshake

```bash
openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" -tls1_3 < /dev/null
```

### 4) Timing metrics

```bash
curl -o /dev/null -sS --tlsv1.3 --connect-timeout 6 --max-time 6 \
  -w "dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}\n" \
  "https://$DOMAIN/"
```

### 5) Ping (auxiliary only)

```bash
ping -c 3 "$DOMAIN"
```

---

## Files and services / Файлы и сервисы

### Files

```text
/opt/mtproxy/
├── mtproto-proxy
├── proxy-secret
├── proxy-multi.conf
├── user-secret
├── mtproxy-info.txt
└── mtproxy-info.env
```

### systemd units

```text
/etc/systemd/system/mtproxy.service
/etc/systemd/system/mtproxy-refresh.service
/etc/systemd/system/mtproxy-refresh.timer
```

### Sysctl fix

```text
/etc/sysctl.d/99-mtproxy-pid.conf
```

---

## Operations / Эксплуатация

### Check MTProxy status

```bash
systemctl status mtproxy
journalctl -u mtproxy -n 100 --no-pager
```

### Check refresh timer

```bash
systemctl status mtproxy-refresh.timer
systemctl list-timers --all | grep mtproxy-refresh
```

### Check local stats endpoint

```bash
curl http://127.0.0.1:8888/stats
```

If custom stats port was selected, replace `8888`.

### Check saved installation info

```bash
cat /opt/mtproxy/mtproxy-info.txt
cat /opt/mtproxy/mtproxy-info.env
```

---

## Troubleshooting

### Port already in use

```bash
ss -tuln | grep ':443'
```

Pick another port in installer prompt.

### Service not starting

```bash
journalctl -u mtproxy -n 100 --no-pager
```

### Validate timer execution

```bash
systemctl status mtproxy-refresh.service
systemctl status mtproxy-refresh.timer
```

### Validate kernel pid_max

```bash
cat /proc/sys/kernel/pid_max
```

Expected value:

```text
32768
```

---

## Author

<p align="center">
  <img src="https://raw.githubusercontent.com/yafoxins/MTProxy-Slayer/main/assets/logo.svg" alt="MTProxy Slayer logo" width="120" />
</p>

<p align="center">
  <b>Yafoxin Dev</b><br/>
  Telegram: <a href="https://t.me/yafoxindev">t.me/yafoxindev</a>
</p>
