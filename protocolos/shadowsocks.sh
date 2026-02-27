#!/bin/bash
# ============================================================
# VPS — Shadowsocks Installer (libev)
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

install_ss() {
    ui_msg_green "INSTALADOR SHADOWSOCKS"
    ui_bar
    
    local port
    port=$(ui_input "Puerto para Shadowsocks" "^[0-9]+$" "1080")

    if is_port_used "$port"; then
        ui_error "Puerto ${port} ya está en uso"
        return 1
    fi
    
    local pass
    pass=$(ui_input "Contraseña para conexión" "" "vpspass123")

    run_with_spinner "Instalando shadowsocks-libev..." "apt-get update -q && apt-get install -y shadowsocks-libev"
    
    # Crear configuración
    cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server": "0.0.0.0",
    "server_port": ${port},
    "password":"${pass}",
    "timeout": 300,
    "method":"aes-256-gcm",
    "fast_open": false
}
EOF

    # Configurar y arrancar el servicio
    systemctl restart shadowsocks-libev
    systemctl enable shadowsocks-libev

    if is_running ss-server; then
        ui_success "Shadowsocks instalado correctamente"
        echo -e "  ${BWHITE}Puerto:${RST}     ${BCYAN}${port}${RST}"
        echo -e "  ${BWHITE}Clave:${RST}      ${BCYAN}${pass}${RST}"
        echo -e "  ${BWHITE}Seguridad:${RST}  ${BCYAN}aes-256-gcm${RST}"
    else
        ui_error "Fallo al arrancar ss-server"
    fi
    
    ui_bar
}

uninstall_ss() {
    if ! ui_confirm "¿Está seguro de eliminar Shadowsocks?"; then
        return
    fi
    systemctl stop shadowsocks-libev
    systemctl disable shadowsocks-libev
    run_with_spinner "Removiendo Shadowsocks..." "apt-get purge -y shadowsocks-libev && rm -rf /etc/shadowsocks-libev"
    ui_success "Shadowsocks eliminado del sistema"

    ui_bar
}

view_config() {
    if [[ -f /etc/shadowsocks-libev/config.json ]]; then
        ui_info "Configuración actual de Shadowsocks:"
        cat /etc/shadowsocks-libev/config.json
    else
        ui_error "No se encuentra el archivo de configuración."
    fi
    ui_bar
}

main() {
    while true; do
        ui_clear
        ui_bar
        ui_title_small
        echo -e "${THEME_HEADER}          SHADOWSOCKS-LIBEV${RST}"
        ui_bar

        local st
        if is_running ss-server; then
            st="${STATUS_ON}"
        else
            st="${STATUS_OFF}"
        fi

        ui_menu_item 1 "Instalar Shadowsocks" "$st"
        ui_menu_item 2 "Ver Configuración / Credenciales"
        ui_menu_item 3 "Desinstalar Shadowsocks"
        ui_bar
        ui_menu_back 0
        ui_bar
        
        local sel
        sel=$(ui_select 3)
        case "$sel" in
            1)
                if [[ "$st" == "${STATUS_ON}" ]]; then
                    ui_error "Shadowsocks ya está instalado."
                    ui_pause
                else
                    install_ss
                    ui_pause
                fi
                ;;
            2)
                view_config
                ui_pause
                ;;
            3)
                uninstall_ss
                ui_pause
                ;;
            0) return ;;
        esac
    done
}

main