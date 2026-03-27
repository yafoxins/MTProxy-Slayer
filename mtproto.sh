#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_VERSION="2.0.0"
readonly WORKDIR="/opt/mtproxy"
readonly SRCDIR="/usr/local/src/MTProxy"
readonly SERVICE_NAME="mtproxy"
readonly REFRESH_NAME="mtproxy-refresh"
readonly PID_CONF="/etc/sysctl.d/99-mtproxy-pid.conf"
readonly INFO_TXT="${WORKDIR}/mtproxy-info.txt"
readonly INFO_ENV="${WORKDIR}/mtproxy-info.env"
readonly PID_TARGET="32768"
readonly RECOMMENDED_PORT="443"
readonly CURL_TIMEOUT="6"
readonly DOMAIN_PROBES="3"

readonly DEFAULT_DOMAIN_CANDIDATES=(
  "yandex.ru"
  "vk.com"
  "vk.ru"
  "petrovich.ru"
  "google.com"
  "ozon.ru"
  "avito.ru"
  "mail.ru"
  "wildberries.ru"
  "gosuslugi.ru"
)

PORT_INPUT_DEFAULT="${PORT:-${RECOMMENDED_PORT}}"
PORT=""
STATS_PORT="${STATS_PORT:-8888}"
FAKE_TLS_DOMAIN="${FAKE_TLS_DOMAIN:-}"
MODE=""
SECRET=""
CLIENT_SECRET=""
DOMAIN_SELECTION_TABLE=""
HOST_IP=""
CURRENT_PID_MAX=""

# ANSI colors
readonly C_RESET='\033[0m'
readonly C_INFO='\033[1;34m'
readonly C_WARN='\033[1;33m'
readonly C_ERROR='\033[1;31m'
readonly C_SUCCESS='\033[1;32m'
readonly C_STEP='\033[1;36m'

CURRENT_STEP=0
TOTAL_STEPS=12

log_info() { printf "%b[INFO]%b %s\n" "${C_INFO}" "${C_RESET}" "$*"; }
log_warn() { printf "%b[WARN]%b %s\n" "${C_WARN}" "${C_RESET}" "$*"; }
log_error() { printf "%b[ERROR]%b %s\n" "${C_ERROR}" "${C_RESET}" "$*" >&2; }
log_success() { printf "%b[OK]%b %s\n" "${C_SUCCESS}" "${C_RESET}" "$*"; }
log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  printf "\n%b[%d/%d]%b %s\n" "${C_STEP}" "${CURRENT_STEP}" "${TOTAL_STEPS}" "${C_RESET}" "$*"
}

on_error() {
  local exit_code="$1"
  local line_no="$2"
  log_error "Script failed at line ${line_no} (exit code ${exit_code})."
  log_error "Check logs: journalctl -u ${SERVICE_NAME} -n 100 --no-pager"
  exit "${exit_code}"
}
trap 'on_error $? $LINENO' ERR

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "Run as root: sudo bash mtproto.sh"
    exit 1
  fi
}

require_commands() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      log_error "Required command not found: ${cmd}"
      exit 1
    fi
  done
}

print_banner() {
  cat <<'BANNER'
============================================================
 MTProxy Slayer Installer (FakeTLS)
 Clean installer UX • systemd refresh • production-like flow
 Author: Yafoxin Dev (https://t.me/yafoxindev)
============================================================
BANNER
}

is_valid_port() {
  local port="$1"
  [[ "${port}" =~ ^[0-9]+$ ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

is_port_available() {
  local port="$1"
  ! ss -tuln | awk '{print $5}' | grep -Eq "(^|[\[\]:\.])${port}$"
}

is_valid_domain() {
  local domain="$1"
  [[ "${domain}" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

check_dns() {
  local domain="$1"
  getent ahostsv4 "${domain}" >/dev/null 2>&1
}

check_ping() {
  local domain="$1"
  local output
  output="$(ping -c 3 -W 2 "${domain}" 2>/dev/null || true)"
  if [[ -z "${output}" ]]; then
    printf "nan"
    return 0
  fi
  awk -F'/' '/^rtt /{print $5; exit}' <<<"${output}"
}

check_tcp_443() {
  local domain="$1"
  timeout "${CURL_TIMEOUT}" bash -c "</dev/tcp/${domain}/443" >/dev/null 2>&1
}

check_tls13() {
  local domain="$1"
  timeout "${CURL_TIMEOUT}" openssl s_client \
    -connect "${domain}:443" \
    -servername "${domain}" \
    -tls1_3 < /dev/null >/tmp/mtproxy_tls_check.out 2>/tmp/mtproxy_tls_check.err || return 1

  grep -q "Protocol  : TLSv1.3" /tmp/mtproxy_tls_check.out
}

median_from_list() {
  local values="$1"
  local sorted=()
  local count=0

  mapfile -t sorted < <(tr ' ' '\n' <<<"${values}" | grep -E '^[0-9.]+$' | sort -n)
  count=${#sorted[@]}

  if (( count == 0 )); then
    printf "nan"
    return
  fi

  if (( count % 2 == 1 )); then
    printf "%s" "${sorted[count/2]}"
  else
    awk -v a="${sorted[count/2-1]}" -v b="${sorted[count/2]}" 'BEGIN { printf "%.6f", (a+b)/2 }'
  fi
}

format_float() {
  local value="$1"
  if [[ "${value}" == "nan" || -z "${value}" ]]; then
    printf "N/A"
  else
    printf "%.3f" "${value}"
  fi
}

measure_domain_timings() {
  local domain="$1"
  local probe
  local success_count=0
  local tcp_values=()
  local tls_values=()

  for ((probe = 1; probe <= DOMAIN_PROBES; probe++)); do
    local line
    line="$(curl -4 -sS -o /dev/null \
      --connect-timeout "${CURL_TIMEOUT}" \
      --max-time "${CURL_TIMEOUT}" \
      --tlsv1.3 \
      -w '%{time_connect} %{time_appconnect}' \
      "https://${domain}/" 2>/dev/null || true)"

    local tcp_time tls_time
    tcp_time="$(awk '{print $1}' <<<"${line}")"
    tls_time="$(awk '{print $2}' <<<"${line}")"

    if [[ "${tcp_time}" =~ ^[0-9.]+$ && "${tls_time}" =~ ^[0-9.]+$ ]]; then
      tcp_values+=("${tcp_time}")
      tls_values+=("${tls_time}")
      success_count=$((success_count + 1))
    fi
  done

  local tcp_median="nan"
  local tls_median="nan"

  if (( ${#tcp_values[@]} > 0 )); then
    tcp_median="$(median_from_list "${tcp_values[*]}")"
  fi
  if (( ${#tls_values[@]} > 0 )); then
    tls_median="$(median_from_list "${tls_values[*]}")"
  fi

  printf "%s|%s|%s\n" "${success_count}" "${tcp_median}" "${tls_median}"
}

score_domain() {
  local tcp_median="$1"
  local tls_median="$2"
  local ping_avg="$3"

  local tcp_ms tls_ms ping_ms
  tcp_ms="$(awk -v t="${tcp_median}" 'BEGIN { if (t=="nan") print 9999; else print t*1000 }')"
  tls_ms="$(awk -v t="${tls_median}" 'BEGIN { if (t=="nan") print 9999; else print t*1000 }')"
  ping_ms="$(awk -v p="${ping_avg}" 'BEGIN { if (p=="nan" || p=="") print 150; else print p }')"

  awk -v tcp="${tcp_ms}" -v tls="${tls_ms}" -v ping="${ping_ms}" 'BEGIN { printf "%.2f", (0.45*tcp) + (0.45*tls) + (0.10*ping) }'
}

prompt_mode() {
  log_step "Select FakeTLS domain mode"
  echo "1) Use your own SNI/domain (manual mode)"
  echo "2) Auto-select best domain from seed list (recommended)"

  while true; do
    read -r -p "Choose [1-2]: " choice
    case "${choice}" in
      1)
        MODE="manual"
        break
        ;;
      2)
        MODE="auto"
        break
        ;;
      *)
        log_warn "Invalid choice. Enter 1 or 2."
        ;;
    esac
  done
}

prompt_port() {
  log_step "Select MTProxy port"
  log_info "Recommended port: ${RECOMMENDED_PORT}"
  log_info "Press Enter to accept default."

  while true; do
    read -r -p "MTProxy port [default: ${PORT_INPUT_DEFAULT}]: " input_port
    input_port="${input_port:-${PORT_INPUT_DEFAULT}}"

    if ! is_valid_port "${input_port}"; then
      log_warn "Port must be a number in range 1..65535."
      continue
    fi

    if ! is_port_available "${input_port}"; then
      log_warn "Port ${input_port} is already in use. Choose another one."
      ss -tuln | awk -v p=":${input_port}" '$0 ~ p {print}' || true
      continue
    fi

    PORT="${input_port}"
    log_success "Selected port: ${PORT}"
    break
  done
}

prompt_stats_port() {
  local stats_default="${STATS_PORT}"

  while true; do
    read -r -p "Stats port [default: ${stats_default}]: " input_stats
    input_stats="${input_stats:-${stats_default}}"

    if ! is_valid_port "${input_stats}"; then
      log_warn "Stats port must be in range 1..65535."
      continue
    fi

    if [[ "${input_stats}" == "${PORT}" ]]; then
      log_warn "Stats port must differ from MTProxy port (${PORT})."
      continue
    fi

    STATS_PORT="${input_stats}"
    log_success "Selected stats port: ${STATS_PORT}"
    break
  done
}

prompt_manual_domain() {
  log_step "Manual FakeTLS domain selection"

  if [[ -n "${FAKE_TLS_DOMAIN}" ]]; then
    log_info "Environment FAKE_TLS_DOMAIN detected: ${FAKE_TLS_DOMAIN}"
  fi

  while true; do
    local suggested="${FAKE_TLS_DOMAIN:-vk.com}"
    read -r -p "Enter FakeTLS domain [default: ${suggested}]: " user_domain
    user_domain="${user_domain:-${suggested}}"

    if ! is_valid_domain "${user_domain}"; then
      log_warn "Invalid domain format. Try again."
      continue
    fi

    if ! check_dns "${user_domain}"; then
      log_warn "Domain DNS resolution failed from this VPS."
      continue
    fi

    if ! check_tcp_443 "${user_domain}"; then
      log_warn "Domain does not accept TCP/443 from this VPS."
      continue
    fi

    if ! check_tls13 "${user_domain}"; then
      log_warn "TLS 1.3 handshake failed for ${user_domain}."
      continue
    fi

    FAKE_TLS_DOMAIN="${user_domain}"
    log_success "Domain accepted: ${FAKE_TLS_DOMAIN}"
    break
  done
}

select_best_domain() {
  log_step "Auto-selecting best FakeTLS domain"

  local best_domain=""
  local best_score=""
  local any_success=0

  DOMAIN_SELECTION_TABLE=$(printf "domain|dns|tcp443|tls13|ping_avg_ms|tcp_med_s|tls_med_s|score\n")

  local domain
  for domain in "${DEFAULT_DOMAIN_CANDIDATES[@]}"; do
    local dns_status="fail"
    local tcp_status="fail"
    local tls_status="fail"
    local ping_avg="nan"
    local tcp_median="nan"
    local tls_median="nan"
    local score="N/A"

    if check_dns "${domain}"; then
      dns_status="ok"
    fi

    if [[ "${dns_status}" == "ok" ]] && check_tcp_443 "${domain}"; then
      tcp_status="ok"
    fi

    local tls_passes=0
    if [[ "${tcp_status}" == "ok" ]]; then
      local i
      for i in 1 2 3; do
        if check_tls13 "${domain}"; then
          tls_passes=$((tls_passes + 1))
        fi
      done
      if (( tls_passes >= 2 )); then
        tls_status="ok"
      fi
    fi

    if [[ "${tls_status}" == "ok" ]]; then
      ping_avg="$(check_ping "${domain}")"
      local metrics
      metrics="$(measure_domain_timings "${domain}")"
      local successes
      successes="$(cut -d'|' -f1 <<<"${metrics}")"
      tcp_median="$(cut -d'|' -f2 <<<"${metrics}")"
      tls_median="$(cut -d'|' -f3 <<<"${metrics}")"

      if (( successes >= 2 )); then
        score="$(score_domain "${tcp_median}" "${tls_median}" "${ping_avg}")"
        any_success=1

        if [[ -z "${best_score}" ]] || awk -v a="${score}" -v b="${best_score}" 'BEGIN { exit !(a < b) }'; then
          best_score="${score}"
          best_domain="${domain}"
        fi
      else
        tls_status="fail"
        score="N/A"
      fi
    fi

    DOMAIN_SELECTION_TABLE+="${domain}|${dns_status}|${tcp_status}|${tls_status}|$(format_float "${ping_avg}")|$(format_float "${tcp_median}")|$(format_float "${tls_median}")|${score}"$'\n'
  done

  if (( any_success == 0 )) || [[ -z "${best_domain}" ]]; then
    log_warn "No domain passed auto-selection criteria. Falling back to manual mode."
    MODE="manual"
    prompt_manual_domain
    return
  fi

  FAKE_TLS_DOMAIN="${best_domain}"
  log_success "Best domain selected: ${FAKE_TLS_DOMAIN} (score ${best_score})"
}

print_domain_results() {
  if [[ -z "${DOMAIN_SELECTION_TABLE}" ]]; then
    return
  fi

  echo
  printf "%-16s %-4s %-6s %-6s %-11s %-10s %-10s %-8s %-9s\n" \
    "DOMAIN" "DNS" "TCP" "TLS13" "PING(ms)" "TCP(s)" "TLS(s)" "SCORE" "SELECTED"

  while IFS='|' read -r domain dns tcp tls ping tcp_med tls_med score; do
    [[ "${domain}" == "domain" || -z "${domain}" ]] && continue
    local selected="no"
    if [[ "${domain}" == "${FAKE_TLS_DOMAIN}" ]]; then
      selected="yes"
    fi
    printf "%-16s %-4s %-6s %-6s %-11s %-10s %-10s %-8s %-9s\n" \
      "${domain}" "${dns}" "${tcp}" "${tls}" "${ping}" "${tcp_med}" "${tls_med}" "${score}" "${selected}"
  done <<<"${DOMAIN_SELECTION_TABLE}"
  echo
}

stop_old_services() {
  log_step "Stopping previous MTProxy units"
  systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
  systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
  systemctl stop "${REFRESH_NAME}.timer" >/dev/null 2>&1 || true
  systemctl disable "${REFRESH_NAME}.timer" >/dev/null 2>&1 || true
  systemctl stop "${REFRESH_NAME}.service" >/dev/null 2>&1 || true
  systemctl disable "${REFRESH_NAME}.service" >/dev/null 2>&1 || true

  rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  rm -f "/etc/systemd/system/${REFRESH_NAME}.service"
  rm -f "/etc/systemd/system/${REFRESH_NAME}.timer"
}

install_dependencies() {
  log_step "Installing dependencies"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y \
    git curl wget ca-certificates openssl build-essential \
    zlib1g-dev libssl-dev xxd procps iproute2
}

configure_pid_max() {
  log_step "Applying kernel.pid_max compatibility fix"
  cat > "${PID_CONF}" <<EOF_PID
kernel.pid_max = ${PID_TARGET}
EOF_PID

  sysctl --system >/dev/null
  CURRENT_PID_MAX="$(< /proc/sys/kernel/pid_max)"
  log_info "Current kernel.pid_max: ${CURRENT_PID_MAX}"

  if (( CURRENT_PID_MAX > 65535 )); then
    log_error "kernel.pid_max remains too high: ${CURRENT_PID_MAX}"
    exit 1
  fi
}

check_telegram_endpoints() {
  log_step "Checking Telegram proxy endpoints availability"
  curl -4fsSL --max-time 20 https://core.telegram.org/getProxySecret -o /tmp/proxy-secret.test
  curl -4fsSL --max-time 20 https://core.telegram.org/getProxyConfig -o /tmp/proxy-config.test
  rm -f /tmp/proxy-secret.test /tmp/proxy-config.test
}

prepare_workspace() {
  log_step "Preparing workspace and building official MTProxy"
  rm -rf "${WORKDIR}" "${SRCDIR}"
  mkdir -p "${WORKDIR}"

  git clone https://github.com/TelegramMessenger/MTProxy.git "${SRCDIR}"
  make -C "${SRCDIR}"

  if [[ ! -x "${SRCDIR}/objs/bin/mtproto-proxy" ]]; then
    log_error "Build failed: mtproto-proxy binary not found."
    exit 1
  fi

  install -m 0755 "${SRCDIR}/objs/bin/mtproto-proxy" "${WORKDIR}/mtproto-proxy"
}

download_proxy_files() {
  log_step "Downloading Telegram proxy-secret and proxy-multi.conf"
  wget -4 -q https://core.telegram.org/getProxySecret -O "${WORKDIR}/proxy-secret"
  wget -4 -q https://core.telegram.org/getProxyConfig -O "${WORKDIR}/proxy-multi.conf"
}

generate_secrets() {
  log_step "Generating user secret and FakeTLS client secret"
  SECRET="$(openssl rand -hex 16)"
  printf "%s\n" "${SECRET}" > "${WORKDIR}/user-secret"

  local domain_hex
  domain_hex="$(printf '%s' "${FAKE_TLS_DOMAIN}" | xxd -ps -c 999 | tr -d '\n')"
  CLIENT_SECRET="ee${SECRET}${domain_hex}"
}

detect_host_ip() {
  HOST_IP="$(curl -4fsSL --max-time 10 https://ifconfig.me || true)"
  if [[ -z "${HOST_IP}" ]]; then
    HOST_IP="$(curl -4fsSL --max-time 10 https://api.ipify.org || true)"
  fi
  if [[ -z "${HOST_IP}" ]]; then
    log_error "Unable to detect host external IPv4."
    exit 1
  fi
}

write_systemd_units() {
  log_step "Creating systemd service and auto-refresh timer"

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF_SERVICE
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
EOF_SERVICE

  cat > "/etc/systemd/system/${REFRESH_NAME}.service" <<EOF_REFRESH_SERVICE
[Unit]
Description=Refresh MTProxy config and restart service

[Service]
Type=oneshot
ExecStart=/bin/bash -lc 'cd ${WORKDIR} && wget -4 -q https://core.telegram.org/getProxySecret -O proxy-secret && wget -4 -q https://core.telegram.org/getProxyConfig -O proxy-multi.conf && systemctl restart ${SERVICE_NAME}'
EOF_REFRESH_SERVICE

  cat > "/etc/systemd/system/${REFRESH_NAME}.timer" <<EOF_REFRESH_TIMER
[Unit]
Description=Run MTProxy refresh every 4 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=4h
Persistent=true
Unit=${REFRESH_NAME}.service

[Install]
WantedBy=timers.target
EOF_REFRESH_TIMER
}

enable_services() {
  log_step "Enabling and starting services"
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}" >/dev/null
  systemctl restart "${SERVICE_NAME}"
  systemctl enable "${REFRESH_NAME}.timer" >/dev/null
  systemctl restart "${REFRESH_NAME}.timer"

  sleep 3
  if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
    log_error "MTProxy failed to start. Showing last logs:"
    journalctl -u "${SERVICE_NAME}" -n 100 --no-pager || true
    exit 1
  fi

  log_success "Service ${SERVICE_NAME} is active."
}

save_proxy_info() {
  log_step "Saving proxy information"

  local tg_link https_link install_date
  install_date="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  tg_link="tg://proxy?server=${HOST_IP}&port=${PORT}&secret=${CLIENT_SECRET}"
  https_link="https://t.me/proxy?server=${HOST_IP}&port=${PORT}&secret=${CLIENT_SECRET}"

  cat > "${INFO_TXT}" <<EOF_INFO_TXT
MTProxy Slayer installation info
================================
Install date (UTC): ${install_date}
Mode: ${MODE}
Host IP: ${HOST_IP}
Port: ${PORT}
Stats port: ${STATS_PORT}
Selected FakeTLS domain: ${FAKE_TLS_DOMAIN}
Short secret: ${SECRET}
Long client secret: ${CLIENT_SECRET}

Telegram link:
${tg_link}

HTTPS link:
${https_link}

Systemd service: ${SERVICE_NAME}.service
Timer: ${REFRESH_NAME}.timer
Current kernel.pid_max: ${CURRENT_PID_MAX}
EOF_INFO_TXT

  if [[ "${MODE}" == "auto" ]]; then
    {
      echo
      echo "Auto-selection results"
      echo "----------------------"
      echo "${DOMAIN_SELECTION_TABLE}" | sed 's/|/\t/g'
      echo "Selected best domain: ${FAKE_TLS_DOMAIN}"
    } >> "${INFO_TXT}"
  fi

  cat > "${INFO_ENV}" <<EOF_INFO_ENV
INSTALL_DATE_UTC=${install_date}
MODE=${MODE}
HOST_IP=${HOST_IP}
PORT=${PORT}
STATS_PORT=${STATS_PORT}
FAKE_TLS_DOMAIN=${FAKE_TLS_DOMAIN}
SHORT_SECRET=${SECRET}
LONG_CLIENT_SECRET=${CLIENT_SECRET}
TG_LINK=${tg_link}
HTTPS_LINK=${https_link}
SERVICE_NAME=${SERVICE_NAME}.service
TIMER_NAME=${REFRESH_NAME}.timer
KERNEL_PID_MAX=${CURRENT_PID_MAX}
EOF_INFO_ENV

  chmod 600 "${INFO_ENV}"
  log_success "Saved info to ${INFO_TXT} and ${INFO_ENV}"

  echo
  echo "==================== FINAL SUMMARY ===================="
  echo "Mode: ${MODE}"
  echo "IP: ${HOST_IP}"
  echo "Port: ${PORT} (recommended: ${RECOMMENDED_PORT})"
  echo "Stats port: ${STATS_PORT}"
  echo "FakeTLS domain: ${FAKE_TLS_DOMAIN}"
  echo "Client secret: ${CLIENT_SECRET}"
  echo ""
  echo "Telegram link:"
  echo "${tg_link}"
  echo ""
  echo "HTTPS link:"
  echo "${https_link}"
  echo ""
  echo "Info file: ${INFO_TXT}"
  echo "Env file:  ${INFO_ENV}"
  echo "======================================================="

  echo
  echo "Useful checks:"
  echo "  systemctl status ${SERVICE_NAME}"
  echo "  journalctl -u ${SERVICE_NAME} -n 50 --no-pager"
  echo "  systemctl status ${REFRESH_NAME}.timer"
  echo "  systemctl list-timers --all | grep ${REFRESH_NAME}"
  echo "  curl http://127.0.0.1:${STATS_PORT}/stats"
}

main() {
  require_root
  require_commands awk grep sed cut timeout ss getent ping curl openssl xxd systemctl
  print_banner

  prompt_mode
  prompt_port
  prompt_stats_port

  if [[ "${MODE}" == "manual" ]]; then
    prompt_manual_domain
  else
    if [[ -n "${FAKE_TLS_DOMAIN}" ]]; then
      log_warn "FAKE_TLS_DOMAIN env is ignored in auto mode."
    fi
    select_best_domain
    print_domain_results
  fi

  stop_old_services
  install_dependencies
  configure_pid_max
  check_telegram_endpoints
  prepare_workspace
  download_proxy_files
  generate_secrets
  detect_host_ip
  write_systemd_units
  enable_services
  save_proxy_info

  log_success "MTProxy FakeTLS installation completed."
}

main "$@"
