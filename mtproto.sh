#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-443}"
STATS_PORT="${STATS_PORT:-8888}"
WORKDIR="/opt/mtproxy"
SRCDIR="/usr/local/src/MTProxy"
SERVICE_NAME="mtproxy"
REFRESH_NAME="mtproxy-refresh"
FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN:-vk.com}"

if [[ $EUID -ne 0 ]]; then
  echo "Запусти от root: sudo bash mtproxy-install.sh"
  exit 1
fi
echo "[0/14] Script by Yafoxin Dev | https://t.me/yafoxindev"
echo "[1/14] Останавливаю старые сервисы..."
systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
systemctl stop "${REFRESH_NAME}.timer" >/dev/null 2>&1 || true
systemctl disable "${REFRESH_NAME}.timer" >/dev/null 2>&1 || true
systemctl stop "${REFRESH_NAME}.service" >/dev/null 2>&1 || true
systemctl disable "${REFRESH_NAME}.service" >/dev/null 2>&1 || true

rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
rm -f "/etc/systemd/system/${REFRESH_NAME}.service"
rm -f "/etc/systemd/system/${REFRESH_NAME}.timer"

echo "[2/14] Ставлю зависимости..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl wget ca-certificates openssl build-essential zlib1g-dev libssl-dev xxd procps

echo "[3/14] Исправляю kernel.pid_max для совместимости с MTProxy..."
cat > /etc/sysctl.d/99-mtproxy-pid.conf <<'EOF'
kernel.pid_max = 32768
EOF

sysctl --system >/dev/null
CURRENT_PID_MAX="$(cat /proc/sys/kernel/pid_max)"
echo "Текущий kernel.pid_max: ${CURRENT_PID_MAX}"

if [[ "${CURRENT_PID_MAX}" -gt 65535 ]]; then
  echo "Ошибка: kernel.pid_max остался слишком большим (${CURRENT_PID_MAX})"
  exit 1
fi

echo "[4/14] Проверяю доступ к Telegram config endpoints..."
curl -4fsSL --max-time 20 https://core.telegram.org/getProxySecret -o /tmp/proxy-secret.test
curl -4fsSL --max-time 20 https://core.telegram.org/getProxyConfig -o /tmp/proxy-config.test
rm -f /tmp/proxy-secret.test /tmp/proxy-config.test

echo "[5/14] Чищу старые файлы..."
rm -rf "${WORKDIR}" "${SRCDIR}"
mkdir -p "${WORKDIR}"

echo "[6/14] Клонирую официальный MTProxy..."
git clone https://github.com/TelegramMessenger/MTProxy.git "${SRCDIR}"

echo "[7/14] Собираю MTProxy..."
cd "${SRCDIR}"
make

if [[ ! -f "${SRCDIR}/objs/bin/mtproto-proxy" ]]; then
  echo "Ошибка: бинарник mtproto-proxy не собрался"
  exit 1
fi

cp "${SRCDIR}/objs/bin/mtproto-proxy" "${WORKDIR}/mtproto-proxy"
chmod +x "${WORKDIR}/mtproto-proxy"

echo "[8/14] Загружаю proxy-secret и proxy-multi.conf..."
wget -4 -q https://core.telegram.org/getProxySecret -O "${WORKDIR}/proxy-secret"
wget -4 -q https://core.telegram.org/getProxyConfig -O "${WORKDIR}/proxy-multi.conf"

SECRET="$(openssl rand -hex 16)"
echo "${SECRET}" > "${WORKDIR}/user-secret"

DOMAIN_HEX="$(printf '%s' "${FAKE_TLS_DOMAIN}" | xxd -ps -c 999 | tr -d '\n')"
CLIENT_SECRET="ee${SECRET}${DOMAIN_HEX}"

HOST_IP="$(curl -4fsSL --max-time 10 https://ifconfig.me || true)"
if [[ -z "${HOST_IP}" ]]; then
  HOST_IP="$(curl -4fsSL --max-time 10 https://api.ipify.org || true)"
fi

if [[ -z "${HOST_IP}" ]]; then
  echo "Не удалось определить внешний IP"
  exit 1
fi

if ss -tulpn | grep -q ":${PORT} "; then
  echo "Ошибка: порт ${PORT} уже занят"
  ss -tulpn | grep ":${PORT} " || true
  exit 1
fi

echo "[9/14] Создаю systemd сервис MTProxy FakeTLS..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Telegram MTProxy FakeTLS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${WORKDIR}
ExecStart=${WORKDIR}/mtproto-proxy -u nobody -p ${STATS_PORT} -H ${PORT} -S ${SECRET} --aes-pwd ${WORKDIR}/proxy-secret ${WORKDIR}/proxy-multi.conf --domain ${FAKE_TLS_DOMAIN}
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "[10/14] Создаю update service..."
cat > "/etc/systemd/system/${REFRESH_NAME}.service" <<EOF
[Unit]
Description=Refresh MTProxy config and restart service

[Service]
Type=oneshot
ExecStart=/bin/bash -lc 'cd ${WORKDIR} && wget -4 -q https://core.telegram.org/getProxySecret -O proxy-secret && wget -4 -q https://core.telegram.org/getProxyConfig -O proxy-multi.conf && systemctl restart ${SERVICE_NAME}'
EOF


echo "[11/14] Создаю timer на каждые 4 часа..."
cat > "/etc/systemd/system/${REFRESH_NAME}.timer" <<EOF
[Unit]
Description=Run MTProxy refresh every 4 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=4h
Persistent=true
Unit=${REFRESH_NAME}.service

[Install]
WantedBy=timers.target
EOF

echo "[12/14] Применяю systemd..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"
systemctl enable "${REFRESH_NAME}.timer"
systemctl restart "${REFRESH_NAME}.timer"

sleep 3

echo "[13/14] Проверяю запуск..."
if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
  echo
  echo "MTProxy не запустился. Последние логи:"
  journalctl -u "${SERVICE_NAME}" -n 100 --no-pager
  exit 1
fi

echo "[14/14] Готово."

TG_LINK="tg://proxy?server=${HOST_IP}&port=${PORT}&secret=${CLIENT_SECRET}"
HTTPS_LINK="https://t.me/proxy?server=${HOST_IP}&port=${PORT}&secret=${CLIENT_SECRET}"

echo
echo "========================================"
echo "MTProxy FakeTLS успешно установлен"
echo "IP: ${HOST_IP}"
echo "PORT: ${PORT}"
echo "DOMAIN: ${FAKE_TLS_DOMAIN}"
echo "SECRET: ${CLIENT_SECRET}"
echo "kernel.pid_max: ${CURRENT_PID_MAX}"
echo
echo "Telegram:"
echo "${TG_LINK}"
echo
echo "HTTPS:"
echo "${HTTPS_LINK}"
echo "========================================"
echo
echo "Проверка MTProxy:"
echo "systemctl status ${SERVICE_NAME}"
echo "journalctl -u ${SERVICE_NAME} -n 50 --no-pager"
echo "curl http://127.0.0.1:${STATS_PORT}/stats || true"
echo
echo "Проверка таймера:"
echo "systemctl status ${REFRESH_NAME}.timer"
echo "systemctl list-timers --all | grep ${REFRESH_NAME}"
echo
echo "Проверка pid_max:"
echo "cat /proc/sys/kernel/pid_max"
