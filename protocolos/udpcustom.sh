#!/bin/bash
# ============================================================
# VPS - Instalador de UDP Custom (ePro Dev)
# ============================================================

source "$(dirname "$(readlink -f "$0")")/../lib/config.sh" 2>/dev/null || source "/etc/VPS/lib/config.sh" 2>/dev/null || true

# Variables
BIN_URL="https://raw.githubusercontent.com/prjkt-nv404/UDP-Custom-Installer-Manager/main/udp-custom"
BIN_DIR="/usr/local/bin"
CFG_DIR="/etc/udp"
CFG_FILE="${CFG_DIR}/config.json"
SVC_FILE="/etc/systemd/system/udp-custom.service"

install_udpcustom() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}              INSTALADOR UDP CUSTOM${RST}"
    ui_bar
    
    # Check if already installed
    if [[ -f "${BIN_DIR}/udp-custom" && -f "$SVC_FILE" ]]; then
        ui_warn "UDP Custom ya esta instalado."
        
        local status=$(service_status "udp-custom")
        echo -e "  ${BWHITE}Estado actual:${RST} $status"
        ui_bar
        
        echo -e " ${THEME_MENU_NUM}[1]${RST} ${THEME_MENU_ARROW}▸${RST} ${BGREEN}Iniciar Servicio${RST}"
        echo -e " ${THEME_MENU_NUM}[2]${RST} ${THEME_MENU_ARROW}▸${RST} ${BYELLOW}Reiniciar Servicio${RST}"
        echo -e " ${THEME_MENU_NUM}[3]${RST} ${THEME_MENU_ARROW}▸${RST} ${BRED}Detener Servicio${RST}"
        echo -e " ${THEME_MENU_NUM}[4]${RST} ${THEME_MENU_ARROW}▸${RST} ${BRED}Desinstalar UDP Custom${RST}"
        ui_bar
        ui_menu_back 0
        ui_bar
        
        local sel=$(ui_select 4)
        case "$sel" in
            1) systemctl start udp-custom; ui_success "Servicio iniciado" ;;
            2) systemctl restart udp-custom; ui_success "Servicio reiniciado" ;;
            3) systemctl stop udp-custom; ui_success "Servicio detenido" ;;
            4) uninstall_udpcustom; return ;;
            0) return ;;
        esac
        ui_pause
        return
    fi
    
    echo -e " ${BCYAN}ℹ${RST} ${BWHITE}UDP Custom${RST} permite realizar llamadas de voz y video"
    echo -e "   por WhatsApp/Telegram en apps como HTTP Custom"
    echo -e "   sin necesidad de usar BadVPN."
    echo ""
    if ! ui_confirm "¿Desea instalar UDP Custom?" "s"; then
        return
    fi
    
    ui_bar
    
    # Descargar binario
    run_with_spinner "Descargando binario UDP Custom..." "wget -q -O ${BIN_DIR}/udp-custom ${BIN_URL} && chmod +x ${BIN_DIR}/udp-custom"
    if [[ ! -f "${BIN_DIR}/udp-custom" ]]; then
        ui_error "Fallo la descarga del binario."
        ui_pause
        return
    fi
    
    # Crear configuracion
    run_with_spinner "Creando configuracion..." "mkdir -p ${CFG_DIR}"
    
    cat > "$CFG_FILE" << EOF
{
  "listen": ":1-65535",
  "max_connections": 1024,
  "max_clients": 1000
}
EOF

    # Crear servicio systemd
    run_with_spinner "Creando servicio systemd..." "true"
    cat > "$SVC_FILE" << EOF
[Unit]
Description=UDP Custom by ePro Dev
After=network.target

[Service]
User=root
Type=simple
ExecStart=/usr/local/bin/udp-custom server -exclude 53,5300
WorkingDirectory=/root
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Iniciar servicio
    run_with_spinner "Iniciando servicio..." "systemctl daemon-reload && systemctl enable udp-custom && systemctl start udp-custom"
    
    ui_bar
    if systemctl is-active --quiet udp-custom; then
        ui_success "UDP Custom instalado y ejecutandose correctamente."
        echo -e " ${BCYAN}ℹ${RST} Puertos habilitados: ${BWHITE}1 al 65535${RST} (excepto DNS 53)"
    else
        ui_error "El servicio se instalo pero fallo al iniciar."
        echo -e " Revisa los logs con: ${BWHITE}journalctl -u udp-custom -e${RST}"
    fi
    ui_pause
}

uninstall_udpcustom() {
    if ! ui_confirm "¿Esta seguro de eliminar UDP Custom?" "n"; then
        return
    fi
    
    run_with_spinner "Deteniendo servicios..." "systemctl stop udp-custom && systemctl disable udp-custom"
    run_with_spinner "Eliminando archivos..." "rm -f $SVC_FILE ${BIN_DIR}/udp-custom && rm -rf $CFG_DIR"
    systemctl daemon-reload
    
    ui_success "UDP Custom ha sido desinstalado completamente."
}

# Ejecutar
install_udpcustom
