#!/usr/bin/env bash
# Instala Zabbix Agent 2 en Debian
# Uso: sudo ./install_zabbix_agent2.sh <IP_SERVIDOR_ZABBIX> [VERSION_ZABBIX]
# Ejemplo: sudo ./install_zabbix_agent2.sh 192.168.1.10 7.0

set -euo pipefail

ZBX_SERVER="${1:-}"
ZBX_VERSION="${2:-7.0}"
CONF="/etc/zabbix/zabbix_agent2.conf"

if [[ -z "$ZBX_SERVER" ]]; then
    echo "Uso: $0 <IP_SERVIDOR_ZABBIX> [VERSION_ZABBIX]" >&2
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta el script como root (sudo)." >&2
    exit 1
fi

# Versión de Debian (11, 12, 13...)
. /etc/os-release
if [[ "${ID:-}" != "debian" ]]; then
    echo "Este script es solo para Debian." >&2
    exit 1
fi
DEB_VER="${VERSION_ID%%.*}"

HOSTNAME_LINUX="$(hostname)"

echo "[*] Debian $DEB_VER | Zabbix $ZBX_VERSION | Servidor: $ZBX_SERVER | Hostname: $HOSTNAME_LINUX"

# Repositorio oficial de Zabbix
apt-get update -y
apt-get install -y wget ca-certificates

PKG="zabbix-release_latest_${ZBX_VERSION}+debian${DEB_VER}_all.deb"
URL="https://repo.zabbix.com/zabbix/${ZBX_VERSION}/debian/pool/main/z/zabbix-release/${PKG}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

wget -q -O "$TMP/$PKG" "$URL"
dpkg -i "$TMP/$PKG"
apt-get update -y

# Instalación del agente
apt-get install -y zabbix-agent2

# Configuración
cp -a "$CONF" "${CONF}.bak.$(date +%F_%H%M%S)"

set_param() {
    local key="$1" value="$2"
    if grep -qE "^[#[:space:]]*${key}=" "$CONF"; then
        # Sustituye la primera aparición (comentada o no) y elimina duplicados activos
        sed -i -E "0,/^[#[:space:]]*${key}=.*/s||${key}=${value}|" "$CONF"
    else
        echo "${key}=${value}" >> "$CONF"
    fi
}

set_param "Server"       "$ZBX_SERVER"
set_param "ServerActive" "$ZBX_SERVER"
set_param "Hostname"     "$HOSTNAME_LINUX"

# Servicio
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2

echo "[+] Zabbix Agent 2 instalado y en ejecución:"
grep -E "^(Server|ServerActive|Hostname)=" "$CONF"
systemctl --no-pager --lines=0 status zabbix-agent2
