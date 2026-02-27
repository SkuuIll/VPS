#!/bin/bash
# ============================================================
# VPS — SSL/Stunnel Installer
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

# ── Instalar SSL/Stunnel ──
install_ssl() {
    ui_msg_green "INSTALADOR SSL By VPS"
    ui_bar

    # ── Seleccionar puerto local de redirección ──
    ui_info "Seleccione un puerto de redirección interna."
    ui_info "Debe ser un puerto SSH/DROPBEAR/SQUID/OPENVPN activo"
    ui_bar

    local ports_list
    ports_list=$(get_ports)

    if [[ -z "$ports_list" ]]; then
        ui_error "No se detectaron servicios activos"
        return 1
    fi

    echo -e "${BWHITE}  Puertos activos:${RST}"
    echo "$ports_list" | while read -r svc port; do
        printf "    ${BGREEN}%-15s${RST} ${BCYAN}%s${RST}\n" "$svc" "$port"
    done
    ui_bar

    local local_port
    while true; do
        local_port=$(ui_input "Puerto local (redirección)")
        if echo "$ports_list" | grep -qw "$local_port"; then
            break
        fi
        ui_error "Puerto no encontrado entre los activos"
    done

    # ── Seleccionar puerto SSL ──
    local ssl_port
    while true; do
        ssl_port=$(ui_input "Puerto SSL (listen)")
        if ! is_port_used "$ssl_port"; then
            break
        fi
        ui_error "Puerto ${ssl_port} ya está en uso"
    done

    # ── Instalar stunnel4 ──
    run_with_spinner "Instalando stunnel4..." "apt-get install -y stunnel4"

    # ── Generar certificado auto-firmado ──
    ui_step "Generando certificado SSL..."
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=MX/ST=VPS/L=MX/O=VPS/CN=$(get_ip)" \
        -keyout /etc/stunnel/stunnel.key \
        -out /etc/stunnel/stunnel.crt 2>/dev/null

    cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > /etc/stunnel/stunnel.pem

    # ── Configurar stunnel ──
    cat > /etc/stunnel/stunnel.conf << EOF
client = no
[SSL]
cert = /etc/stunnel/stunnel.pem
accept = ${ssl_port}
connect = 127.0.0.1:${local_port}
EOF

    # ── Habilitar y arrancar ──
    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
    service_ctl restart stunnel4

    # ── Limpiar temporales ──
    rm -f /etc/stunnel/stunnel.key /etc/stunnel/stunnel.crt 2>/dev/null

    ui_bar
    ui_success "SSL instalado correctamente"
    echo -e "  ${BWHITE}Puerto local:${RST} ${BCYAN}${local_port}${RST}"
    echo -e "  ${BWHITE}Puerto SSL:${RST}   ${BGREEN}${ssl_port}${RST}"
    ui_bar
}

# ── Agregar más puertos SSL ──
add_ssl_port() {
    ui_msg_green "AGREGAR MÁS PUERTOS SSL"
    ui_bar

    if [[ ! -f /etc/stunnel/stunnel.conf ]]; then
        ui_error "Stunnel no está instalado. Use la opción 1 primero."
        return 1
    fi

    local ports_list
    ports_list=$(get_ports)

    local local_port
    while true; do
        local_port=$(ui_input "Puerto local (redirección)")
        if echo "$ports_list" | grep -qw "$local_port"; then
            break
        fi
        ui_error "Puerto no encontrado entre los activos"
    done

    local ssl_port
    while true; do
        ssl_port=$(ui_input "Nuevo puerto SSL")
        if ! is_port_used "$ssl_port"; then
            break
        fi
        ui_error "Puerto ${ssl_port} ya está en uso"
    done

    backup_file /etc/stunnel/stunnel.conf

    cat >> /etc/stunnel/stunnel.conf << EOF

[SSL-${ssl_port}]
cert = /etc/stunnel/stunnel.pem
accept = ${ssl_port}
connect = 127.0.0.1:${local_port}
EOF

    service_ctl restart stunnel4
    ui_success "Puerto SSL agregado: ${BGREEN}${ssl_port}${RST} → ${BCYAN}${local_port}${RST}"
    ui_bar
}

# ── Desinstalar SSL ──
uninstall_ssl() {
    if ! is_running stunnel4; then
        ui_warn "Stunnel no está activo"
        return
    fi

    if ui_confirm "¿Desinstalar Stunnel4?"; then
        service_ctl stop stunnel4
        run_with_spinner "Desinstalando stunnel4..." "apt-get purge -y stunnel4"
        ui_success "Stunnel4 desinstalado"
    fi
    ui_bar
}

# ── SSL + Python Direct (auto-config) ──
ssl_auto_config() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${BYELLOW}      SSL + PYTHON DIRECT (AUTO CONFIGURACIÓN)${RST}"
    ui_bar
    ui_warn "Requiere puerto 22 SSH y puertos 80, 443 libres"
    ui_bar

    if is_port_used 80 || is_port_used 443; then
        ui_error "Puertos 80 o 443 ya están en uso"
        return 1
    fi

    # Instalar Python proxy en puerto 80
    ui_step "Activando Python Direct en puerto 80..."
    ensure_package python3
    if [[ -f "${VPS_PROTO}/PDirect.py" ]]; then
        screen -dmS pydic-80 python3 "${VPS_PROTO}/PDirect.py" 80 "VPS" 2>/dev/null
    fi

    # Instalar SSL 80 → 443
    ui_step "Configurando SSL 80 → 443..."
    run_with_spinner "Instalando stunnel4..." "apt-get install -y stunnel4"

    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=MX/ST=VPS/L=MX/O=VPS/CN=$(get_ip)" \
        -keyout /etc/stunnel/stunnel.key \
        -out /etc/stunnel/stunnel.crt 2>/dev/null

    cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > /etc/stunnel/stunnel.pem
    rm -f /etc/stunnel/stunnel.key /etc/stunnel/stunnel.crt

    cat > /etc/stunnel/stunnel.conf << 'EOF'
client = no
[SSL]
cert = /etc/stunnel/stunnel.pem
accept = 443
connect = 127.0.0.1:80
EOF

    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
    service_ctl restart stunnel4

    ui_bar
    ui_success "INSTALACIÓN COMPLETA"
    echo -e "  ${BWHITE}Python Direct:${RST} puerto ${BCYAN}80${RST}"
    echo -e "  ${BWHITE}SSL Stunnel:${RST}   puerto ${BGREEN}443${RST} → 80"
    ui_bar
}

# ── Menú principal ──
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}       INSTALADOR SSL/STUNNEL${RST}"
    ui_bar

    local stunnel_st=$(service_status stunnel4)

    ui_menu_item 1 "Instalar / Desinstalar SSL" "$stunnel_st"
    ui_menu_item 2 "Agregar más puertos SSL"
    ui_menu_item 3 "SSL + Python Direct (auto-config)"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 3)

    case "$sel" in
        1)
            if is_running stunnel4; then
                uninstall_ssl
            else
                install_ssl
            fi
            ;;
        2) add_ssl_port ;;
        3) ssl_auto_config ;;
        0) return ;;
    esac
}

main
