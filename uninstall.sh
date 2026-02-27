#!/bin/bash
# ============================================================
# VPS — Desinstalador
# ============================================================
set -euo pipefail

RST='\033[0m'
BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'

INSTALL_DIR="/etc/VPS"

bar() {
    printf "${BYELLOW}"
    printf '%60s' '' | tr ' ' '━'
    printf "${RST}\n"
}

# ── Verificar root ──
if [[ $EUID -ne 0 ]]; then
    echo -e "${BRED}Error: Ejecutar como root${RST}"
    exit 1
fi

clear
bar
echo -e "${BRED}  ⚠  DESINSTALADOR VPS${RST}"
bar
echo ""
echo -e "  ${BWHITE}Esto eliminará:${RST}"
echo -e "  ${BRED}•${RST} Panel VPS (${INSTALL_DIR})"
echo -e "  ${BRED}•${RST} Comandos CLI (VPS, vps)"
echo -e "  ${BRED}•${RST} Servicios systemd de VPS"
echo ""
echo -e "  ${BYELLOW}Los servicios instalados (squid, stunnel4, dropbear,${RST}"
echo -e "  ${BYELLOW}openvpn, etc.) NO serán eliminados.${RST}"
echo ""
bar

echo -ne " ${BWHITE}¿Crear backup antes de desinstalar? [S/n]:${RST} "
read -r backup_answer
backup_answer="${backup_answer:-s}"

if [[ "$backup_answer" == @(s|S|y|Y) ]]; then
    backup_name="/root/VPS-backup-$(date +%Y%m%d_%H%M%S)"
    if [[ -d "$INSTALL_DIR" ]]; then
        cp -r "$INSTALL_DIR" "$backup_name"
        echo -e " ${BGREEN}✔${RST} Backup creado: ${BWHITE}${backup_name}${RST}"
    fi
fi

echo ""
echo -ne " ${BRED}¿CONFIRMAR DESINSTALACIÓN? [s/N]:${RST} "
read -r confirm
if [[ "$confirm" != @(s|S|y|Y) ]]; then
    echo -e " ${BYELLOW}Cancelado${RST}"
    exit 0
fi

echo ""

# Parar servicios systemd
echo -e " ${BCYAN}▸${RST} Deteniendo servicios..."
systemctl stop badvpn-udpgw 2>/dev/null || true
systemctl disable badvpn-udpgw 2>/dev/null || true
rm -f /etc/systemd/system/badvpn-udpgw.service 2>/dev/null
systemctl stop vps-monitor 2>/dev/null || true
systemctl disable vps-monitor 2>/dev/null || true
rm -f /etc/systemd/system/vps-monitor.service 2>/dev/null
systemctl daemon-reload 2>/dev/null || true

# Matar procesos relacionados
echo -e " ${BCYAN}▸${RST} Deteniendo procesos..."
pkill -f 'badvpn-udpgw' 2>/dev/null || true
pkill -f 'PGet.py\|POpen.py\|PPriv.py\|PPub.py\|PDirect.py' 2>/dev/null || true

# Eliminar comandos CLI
echo -e " ${BCYAN}▸${RST} Eliminando comandos..."
rm -f /usr/local/bin/VPS /usr/local/bin/vps 2>/dev/null
rm -f /usr/bin/vps /usr/bin/VPS /bin/VPS /bin/menu 2>/dev/null

# Eliminar sysctl config
rm -f /etc/sysctl.d/99-vps.conf 2>/dev/null
sysctl --system > /dev/null 2>&1 || true

# Eliminar directorio principal
echo -e " ${BCYAN}▸${RST} Eliminando archivos..."
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
fi

echo ""
bar
echo -e " ${BGREEN}✔${RST} VPS desinstalado completamente"
[[ -n "${backup_name:-}" ]] && echo -e " ${BCYAN}ℹ${RST} Tu backup está en: ${BWHITE}${backup_name}${RST}"
bar
echo ""
