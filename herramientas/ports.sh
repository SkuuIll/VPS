#!/bin/bash
# ============================================================
# VPS — Administrar Puertos Activos
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

# ── Verificar que un puerto no está en uso por otro servicio ──
verify_port_available() {
    local service="$1"
    local port="$2"

    # Verificar rango válido
    if ! validate_port "$port"; then
        ui_error "Puerto inválido: ${port} (debe ser 1-65535)"
        return 1
    fi

    # Verificar que no está en uso por otro servicio
    local current_user
    current_user=$(ss -tlnp 2>/dev/null | grep ":${port}\b" | grep -oP '(?<=\(\(")[^"]+' | head -1)
    if [[ -n "$current_user" && "$current_user" != "$service" ]]; then
        ui_error "Puerto ${port} en uso por: ${current_user}"
        return 1
    fi
    return 0
}

# ── Editar puertos Squid ──
edit_squid() {
    ui_msg_yellow "REDEFINIR PUERTOS SQUID"
    ui_bar

    local conf=""
    [[ -f /etc/squid/squid.conf ]] && conf="/etc/squid/squid.conf"
    [[ -f /etc/squid3/squid.conf ]] && conf="/etc/squid3/squid.conf"

    if [[ -z "$conf" ]]; then
        ui_error "Squid no está instalado"
        return 1
    fi

    backup_file "$conf"

    local ports
    ports=$(ui_input "Nuevos puertos (separados por espacio)" "^[0-9 ]+$")

    for p in $ports; do
        if ! verify_port_available squid "$p"; then return 1; fi
    done

    # Reconfigurar puertos
    local newconf
    newconf=$(grep -v "^http_port" "$conf")
    echo "$newconf" > "$conf"
    for p in $ports; do
        sed -i "/^#portas/a http_port ${p}" "$conf"
    done

    run_with_spinner "Reiniciando Squid..." "service squid restart; service squid3 restart"
    ui_success "Puertos Squid redefinidos: ${ports}"
    ui_bar
}

# ── Editar puertos Apache ──
edit_apache() {
    ui_msg_yellow "REDEFINIR PUERTOS APACHE"
    ui_bar

    local conf="/etc/apache2/ports.conf"
    if [[ ! -f "$conf" ]]; then
        ui_error "Apache no está instalado"
        return 1
    fi

    backup_file "$conf"

    local port
    port=$(ui_input "Nuevo puerto Apache" "^[0-9]+$")

    if ! verify_port_available apache2 "$port"; then return 1; fi

    sed -i "s/^Listen .*/Listen ${port}/" "$conf"
    run_with_spinner "Reiniciando Apache..." "service apache2 restart"
    ui_success "Puerto Apache: ${port}"
    ui_bar
}

# ── Editar puertos OpenVPN ──
edit_openvpn() {
    ui_msg_yellow "REDEFINIR PUERTOS OPENVPN"
    ui_bar

    local conf="/etc/openvpn/server.conf"
    local conf2="/etc/openvpn/client-common.txt"

    if [[ ! -f "$conf" ]]; then
        ui_error "OpenVPN no está instalado"
        return 1
    fi

    backup_file "$conf"
    [[ -f "$conf2" ]] && backup_file "$conf2"

    local port
    port=$(ui_input "Nuevo puerto OpenVPN" "^[0-9]+$")

    if ! verify_port_available openvpn "$port"; then return 1; fi

    sed -i "s/^port .*/port ${port}/" "$conf"

    if [[ -f "$conf2" ]]; then
        sed -i "s/^\(remote [^ ]* \)[0-9]*/\1${port}/" "$conf2"
    fi

    run_with_spinner "Reiniciando OpenVPN..." "service openvpn restart"
    ui_success "Puerto OpenVPN: ${port}"
    ui_bar
}

# ── Editar puertos Dropbear ──
edit_dropbear() {
    ui_msg_yellow "REDEFINIR PUERTOS DROPBEAR"
    ui_bar

    local conf="/etc/default/dropbear"
    if [[ ! -f "$conf" ]]; then
        ui_error "Dropbear no está instalado"
        return 1
    fi

    backup_file "$conf"

    local ports
    ports=$(ui_input "Nuevos puertos (separados por espacio)" "^[0-9 ]+$")

    for p in $ports; do
        if ! verify_port_available dropbear "$p"; then return 1; fi
    done

    # Construir argumento -p para cada puerto
    local args=""
    for p in $ports; do
        args+="-p ${p} "
    done

    sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"${args}\"/" "$conf"

    run_with_spinner "Reiniciando Dropbear..." "service dropbear restart"
    ui_success "Puertos Dropbear: ${ports}"
    ui_bar
}

# ── Editar puertos OpenSSH ──
edit_openssh() {
    ui_msg_yellow "REDEFINIR PUERTOS OPENSSH"
    ui_bar

    local conf="/etc/ssh/sshd_config"
    backup_file "$conf"

    local ports
    ports=$(ui_input "Nuevos puertos (separados por espacio)" "^[0-9 ]+$")

    for p in $ports; do
        if ! verify_port_available sshd "$p"; then return 1; fi
    done

    # Eliminar líneas Port existentes y agregar nuevas
    sed -i '/^Port /d' "$conf"
    for p in $ports; do
        sed -i "1i Port ${p}" "$conf"
    done

    run_with_spinner "Reiniciando SSH..." "service ssh restart; service sshd restart"
    ui_success "Puertos SSH: ${ports}"
    ui_bar
}

# ── Menú principal ──
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}            EDITAR PUERTOS ACTIVOS${RST}"
    ui_bar

    # Detectar servicios instalados
    local num=0
    local options=()

    local detected_services
    detected_services=$(get_ports | awk '{print $1}' | sort -u)

    if echo "$detected_services" | grep -qw "squid\|squid3"; then
        (( num++ )); options+=("squid")
        ui_menu_item "$num" "Redefinir puertos SQUID"
    fi
    if echo "$detected_services" | grep -qw "apache\|apache2"; then
        (( num++ )); options+=("apache")
        ui_menu_item "$num" "Redefinir puertos APACHE"
    fi
    if echo "$detected_services" | grep -qw "openvpn"; then
        (( num++ )); options+=("openvpn")
        ui_menu_item "$num" "Redefinir puertos OPENVPN"
    fi
    if echo "$detected_services" | grep -qw "dropbear"; then
        (( num++ )); options+=("dropbear")
        ui_menu_item "$num" "Redefinir puertos DROPBEAR"
    fi
    if echo "$detected_services" | grep -qw "sshd"; then
        (( num++ )); options+=("ssh")
        ui_menu_item "$num" "Redefinir puertos SSH"
    fi

    if [[ $num -eq 0 ]]; then
        ui_warn "No se detectaron servicios activos con puertos TCP"
        ui_bar
        return
    fi

    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select "$num")
    [[ "$sel" -eq 0 ]] && return

    case "${options[$((sel-1))]}" in
        squid)    edit_squid ;;
        apache)   edit_apache ;;
        openvpn)  edit_openvpn ;;
        dropbear) edit_dropbear ;;
        ssh)      edit_openssh ;;
    esac
}

main