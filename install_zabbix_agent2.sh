#!/usr/bin/env bash
# Instala Zabbix Agent 2 en Debian y Ubuntu
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

# Detección de distribución y versión
. /etc/os-release
case "${ID:-}" in
    debian)
        DISTRO="debian"
        DISTRO_VER="${VERSION_ID%%.*}"      # 11, 12, 13...
        ;;
    ubuntu)
        DISTRO="ubuntu"
        DISTRO_VER="${VERSION_ID}"          # 22.04, 24.04...
        ;;
    *)
        echo "Distribución no soportada: ${ID:-desconocida}. Solo Debian y Ubuntu." >&2
        exit 1
        ;;
esac

HOSTNAME_LINUX="$(hostname)"

echo "[*] ${DISTRO^} $DISTRO_VER | Zabbix $ZBX_VERSION | Servidor: $ZBX_SERVER | Hostname: $HOSTNAME_LINUX"

# Repositorio oficial de Zabbix
apt-get update -y
apt-get install -y wget ca-certificates

PKG="zabbix-release_latest_${ZBX_VERSION}+${DISTRO}${DISTRO_VER}_all.deb"
URL="https://repo.zabbix.com/zabbix/${ZBX_VERSION}/${DISTRO}/pool/main/z/zabbix-release/${PKG}"

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
    # Elimina cualquier línea activa del parámetro (valores por defecto incluidos)
    sed -i -E "/^[[:space:]]*${key}[[:space:]]*=/d" "$CONF"
    # Añade el valor nuevo
    echo "${key}=${value}" >> "$CONF"
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
