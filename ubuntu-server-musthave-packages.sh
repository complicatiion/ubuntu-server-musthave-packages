#!/usr/bin/env bash
# ubuntu-server-musthave-packages
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

OS_ID="$(. /etc/os-release && echo "${ID:-}")"
OS_VER="$(. /etc/os-release && echo "${VERSION_ID:-}")"
OS_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"

if [[ "$OS_ID" != "ubuntu" ]]; then
  warn "This script is intended for Ubuntu. Detected: ${OS_ID:-unknown}"
fi

# Best-effort version gate (Ubuntu 24.04+ recommended)
if [[ "$OS_VER" =~ ^([0-9]+)\. ]]; then
  major="${BASH_REMATCH[1]}"
  if (( major < 24 )); then
    warn "Ubuntu ${OS_VER} detected. Recommended: Ubuntu Server 24.04+"
  fi
fi

apt_update_once_done=0
apt_update_once() {
  if (( apt_update_once_done == 0 )); then
    log "Updating APT index..."
    apt-get update -y
    apt_update_once_done=1
  fi
}

apt_install() {
  local pkgs=("$@")
  apt_update_once
  apt-get install -y "${pkgs[@]}"
}

has_line_in_sources() {
  local pattern="$1"
  grep -RqsE "$pattern" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null
}

ensure_add_apt_repository() {
  if ! command -v add-apt-repository >/dev/null 2>&1; then
    apt_install software-properties-common
  fi
}

ensure_universe() {
  # Enable if "universe" is missing in enabled deb lines
  if ! has_line_in_sources '^[[:space:]]*deb[[:space:]].*[[:space:]]universe([[:space:]]|$)'; then
    ensure_add_apt_repository
    log "Enabling Ubuntu 'universe' repository..."
    add-apt-repository -y universe >/dev/null
    apt_update_once_done=0
  fi
}

ensure_backports() {
  # Backports are optional; enable only when needed
  local codename="${OS_CODENAME:-noble}"
  if ! has_line_in_sources "^[[:space:]]*deb[[:space:]].*[[:space:]]${codename}-backports([[:space:]]|$)"; then
    log "Enabling Ubuntu '${codename}-backports' repository..."
    cat >/etc/apt/sources.list.d/"${codename}"-backports.list <<EOF
deb http://archive.ubuntu.com/ubuntu ${codename}-backports main restricted universe multiverse
EOF
    apt_update_once_done=0
  fi
}

service_enable_now() {
  local unit="$1"
  systemctl enable --now "$unit" >/dev/null 2>&1 || true
}

ask_yn() {
  local prompt="$1"
  local ans=""
  read -r -p "${prompt} [y/N]: " ans || true
  case "${ans,,}" in
    y|yes) return 0 ;;
    *)     return 1 ;;
  esac
}

# ---- Catalog (ordered) ----
declare -a IDS=(
  COCKPIT
  SSH
  CURL_WGET
  UFW
  NET_TOOLS
  TRACEROUTE
  IPERF3
  IPERF_LEGACY
  MOSH
  XRDP
  AVAHI
  CIFS
  NTP
  HTOP
  IOTOP
  NMON
  NCDU
  GLANCES
  LOGWATCH
  FAIL2BAN
  STRESS
  VIM
  JQ
  BUILD_ESSENTIAL
  PYTHON3
  WEBMIN
)

declare -A CAT NAME DESC PKGS

CAT[COCKPIT]="Web UI / Admin"
NAME[COCKPIT]="Cockpit Web Console"
DESC[COCKPIT]="Web-based server administration UI (port 9090), systemd socket activation."
PKGS[COCKPIT]="cockpit cockpit-podman"

CAT[SSH]="Networking & Remote Access"
NAME[SSH]="OpenSSH Server"
DESC[SSH]="Remote shell access via SSH (port 22)."
PKGS[SSH]="openssh-server"

CAT[CURL_WGET]="Networking & Remote Access"
NAME[CURL_WGET]="curl + wget"
DESC[CURL_WGET]="CLI download tools for APIs/files."
PKGS[CURL_WGET]="curl wget"

CAT[UFW]="Security"
NAME[UFW]="UFW Firewall"
DESC[UFW]="Simple host firewall management."
PKGS[UFW]="ufw"

CAT[NET_TOOLS]="Networking & Remote Access"
NAME[NET_TOOLS]="net-tools"
DESC[NET_TOOLS]="Legacy networking tools (ifconfig, netstat)."
PKGS[NET_TOOLS]="net-tools"

CAT[TRACEROUTE]="Networking & Remote Access"
NAME[TRACEROUTE]="traceroute"
DESC[TRACEROUTE]="Route/path debugging to a host."
PKGS[TRACEROUTE]="traceroute"

CAT[IPERF3]="Networking & Remote Access"
NAME[IPERF3]="iperf3"
DESC[IPERF3]="Network throughput testing (port 5201 when used as server)."
PKGS[IPERF3]="iperf3"

CAT[IPERF_LEGACY]="Networking & Remote Access"
NAME[IPERF_LEGACY]="iperf (legacy)"
DESC[IPERF_LEGACY]="Legacy iperf (prefer iperf3 unless you need v2 compatibility)."
PKGS[IPERF_LEGACY]="iperf"

CAT[MOSH]="Networking & Remote Access"
NAME[MOSH]="mosh"
DESC[MOSH]="Resilient SSH-like terminal (uses UDP 60000-61000)."
PKGS[MOSH]="mosh"

CAT[XRDP]="Networking & Remote Access"
NAME[XRDP]="xrdp"
DESC[XRDP]="RDP server (port 3389). Requires a desktop environment to be useful."
PKGS[XRDP]="xrdp"

CAT[AVAHI]="Networking & Remote Access"
NAME[AVAHI]="Avahi (mDNS/Bonjour)"
DESC[AVAHI]="Zeroconf service discovery on LAN."
PKGS[AVAHI]="avahi-daemon avahi-utils"

CAT[CIFS]="Storage & Filesystems"
NAME[CIFS]="cifs-utils"
DESC[CIFS]="Mount SMB/CIFS shares (Windows file shares)."
PKGS[CIFS]="cifs-utils"

CAT[NTP]="Time"
NAME[NTP]="NTP daemon"
DESC[NTP]="Time synchronization service (NTP)."
PKGS[NTP]="ntp"

CAT[HTOP]="Monitoring"
NAME[HTOP]="htop"
DESC[HTOP]="Interactive process viewer."
PKGS[HTOP]="htop"

CAT[IOTOP]="Monitoring"
NAME[IOTOP]="iotop"
DESC[IOTOP]="Disk I/O usage per process."
PKGS[IOTOP]="iotop"

CAT[NMON]="Monitoring"
NAME[NMON]="nmon"
DESC[NMON]="Performance monitoring (CPU/RAM/Disk/Net)."
PKGS[NMON]="nmon"

CAT[NCDU]="Monitoring"
NAME[NCDU]="ncdu"
DESC[NCDU]="Interactive disk usage analyzer."
PKGS[NCDU]="ncdu"

CAT[GLANCES]="Monitoring"
NAME[GLANCES]="glances"
DESC[GLANCES]="System monitoring dashboard (CLI/Web modes)."
PKGS[GLANCES]="glances"

CAT[LOGWATCH]="Monitoring"
NAME[LOGWATCH]="logwatch"
DESC[LOGWATCH]="Daily log summary (email requires local MTA configuration)."
PKGS[LOGWATCH]="logwatch"

CAT[FAIL2BAN]="Security"
NAME[FAIL2BAN]="fail2ban"
DESC[FAIL2BAN]="Bans malicious IPs based on log patterns."
PKGS[FAIL2BAN]="fail2ban"

CAT[STRESS]="Testing"
NAME[STRESS]="stress"
DESC[STRESS]="Simple CPU/memory load testing."
PKGS[STRESS]="stress"

CAT[VIM]="Admin & Utilities"
NAME[VIM]="vim"
DESC[VIM]="CLI text editor."
PKGS[VIM]="vim"

CAT[JQ]="Admin & Utilities"
NAME[JQ]="jq"
DESC[JQ]="JSON processor for CLI pipelines."
PKGS[JQ]="jq"

CAT[BUILD_ESSENTIAL]="Development"
NAME[BUILD_ESSENTIAL]="build-essential"
DESC[BUILD_ESSENTIAL]="Compilers and build tools."
PKGS[BUILD_ESSENTIAL]="build-essential"

CAT[PYTHON3]="Development"
NAME[PYTHON3]="python3"
DESC[PYTHON3]="Python runtime for scripts and tooling."
PKGS[PYTHON3]="python3"

CAT[WEBMIN]="Web UI / Admin"
NAME[WEBMIN]="Webmin"
DESC[WEBMIN]="Web-based system administration UI (port 10000). Installs via official Webmin repo setup script."
PKGS[WEBMIN]=""  # handled separately

print_overview() {
  log ""
  log "==== Package Overview (Ubuntu ${OS_VER:-?} / ${OS_CODENAME:-?}) ===="
  local categories=( "Web UI / Admin" "Networking & Remote Access" "Security" "Storage & Filesystems" "Time" "Monitoring" "Testing" "Admin & Utilities" "Development" )
  local i id
  for c in "${categories[@]}"; do
    local printed=0
    for id in "${IDS[@]}"; do
      [[ "${CAT[$id]}" == "$c" ]] || continue
      if (( printed == 0 )); then
        log ""
        log "[$c]"
        printf '%-4s %-26s %-34s %s\n' "ID" "Component" "Packages" "Description"
        printf '%-4s %-26s %-34s %s\n' "----" "--------------------------" "----------------------------------" "-----------"
        printed=1
      fi
      local pk="${PKGS[$id]}"
      [[ -n "$pk" ]] || pk="(custom)"
      printf '%-4s %-26s %-34s %s\n' "$id" "${NAME[$id]}" "$pk" "${DESC[$id]}"
    done
  done
  log ""
}

install_webmin() {
  # Official: webmin.com recommends webmin-setup-repo.sh
  apt_install curl ca-certificates gnupg
  apt_update_once
  log "Setting up Webmin repository (official script)..."
  rm -f /tmp/webmin-setup-repo.sh
  curl -fsSL -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
  sh /tmp/webmin-setup-repo.sh >/dev/null
  apt_update_once_done=0
  apt_update_once
  apt-get install -y webmin --install-recommends
}

post_actions() {
  local id="$1"
  case "$id" in
    COCKPIT)
      # Cockpit uses socket activation on most distros
      service_enable_now cockpit.socket
      ;;
    SSH)
      service_enable_now ssh
      ;;
    UFW)
      # Configure later in the dedicated UFW section
      ;;
    XRDP)
      service_enable_now xrdp
      service_enable_now xrdp-sesman
      ;;
    AVAHI)
      service_enable_now avahi-daemon
      ;;
    NTP)
      service_enable_now ntp
      ;;
    FAIL2BAN)
      service_enable_now fail2ban
      ;;
  esac
}

maybe_install_cockpit_podman_backports() {
  # cockpit-podman may be in Universe/Backports depending on release
  local pkgs=(cockpit cockpit-podman)
  ensure_universe
  if ! apt-cache show cockpit-podman >/dev/null 2>&1; then
    # Try backports if not found
    ensure_backports
  fi
  apt_install "${pkgs[@]}"
}

configure_ufw_optional() {
  if ! dpkg -s ufw >/dev/null 2>&1; then
    return 0
  fi

  log ""
  log "==== Optional UFW configuration ===="
  if ! ask_yn "Configure/enable UFW now?"; then
    return 0
  fi

  # Always offer OpenSSH rule first to avoid locking yourself out
  if ask_yn "Allow OpenSSH (recommended before enabling UFW)?"; then
    ufw allow OpenSSH >/dev/null || true
  fi

  # Service-specific rules (only if packages installed)
  if dpkg -s cockpit >/dev/null 2>&1; then
    ask_yn "Allow Cockpit (9090/tcp)?" && ufw allow 9090/tcp >/dev/null || true
  fi
  if dpkg -s webmin >/dev/null 2>&1; then
    ask_yn "Allow Webmin (10000/tcp)?" && ufw allow 10000/tcp >/dev/null || true
  fi
  if dpkg -s xrdp >/dev/null 2>&1; then
    ask_yn "Allow xrdp (3389/tcp)?" && ufw allow 3389/tcp >/dev/null || true
  fi
  if dpkg -s ntp >/dev/null 2>&1; then
    ask_yn "Allow NTP (123/udp)?" && ufw allow 123/udp >/dev/null || true
  fi
  if dpkg -s mosh >/dev/null 2>&1; then
    ask_yn "Allow mosh (60000:61000/udp)?" && ufw allow 60000:61000/udp >/dev/null || true
  fi
  if dpkg -s iperf3 >/dev/null 2>&1; then
    ask_yn "Allow iperf3 server (5201/tcp)?" && ufw allow 5201/tcp >/dev/null || true
  fi

  ufw --force enable >/dev/null || true
  log ""
  ufw status verbose || true
}

main() {
  print_overview

  declare -a installed=() skipped=() failed=()

  for id in "${IDS[@]}"; do
    log ""
    log "---- ${NAME[$id]} ----"
    log "${DESC[$id]}"
    if [[ -n "${PKGS[$id]}" ]]; then
      log "Packages: ${PKGS[$id]}"
    else
      log "Packages: (custom install)"
    fi

    if ! ask_yn "Install ${NAME[$id]}?"; then
      skipped+=("$id")
      continue
    fi

    set +e
    if [[ "$id" == "WEBMIN" ]]; then
      ensure_universe
      install_webmin
      rc=$?
    elif [[ "$id" == "COCKPIT" ]]; then
      maybe_install_cockpit_podman_backports
      rc=$?
    else
      # Some packages live in Universe on certain installs
      ensure_universe
      apt_install ${PKGS[$id]}
      rc=$?
    fi
    set -e

    if (( rc == 0 )); then
      installed+=("$id")
      post_actions "$id"
      log "OK: ${NAME[$id]}"
    else
      failed+=("$id")
      err "Failed: ${NAME[$id]}"
    fi
  done

  configure_ufw_optional

  log ""
  log "==== Summary ===="
  log "Installed: ${#installed[@]}  | Skipped: ${#skipped[@]}  | Failed: ${#failed[@]}"
  ((${#installed[@]})) && printf 'Installed IDs: %s\n' "${installed[*]}" || true
  ((${#skipped[@]}))  && printf 'Skipped IDs:   %s\n' "${skipped[*]}"  || true
  ((${#failed[@]}))   && printf 'Failed IDs:    %s\n' "${failed[*]}"   || true

  log ""
  log "Done."
}

main "$@"