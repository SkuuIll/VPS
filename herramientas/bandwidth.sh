#!/bin/bash
# ============================================================
# VPS-MX -- Limitador de Ancho de Banda por Usuario
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

TC_IFACE=""

# -- Detectar interfaz de red principal --
detect_interface() {
    TC_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$TC_IFACE" ]]; then
        TC_IFACE=$(ip link show | grep -v lo | grep 'state UP' | head -1 | awk -F: '{print $2}' | tr -d ' ')
    fi
}

# -- Verificar si tc esta configurado --
is_tc_active() {
    tc qdisc show dev "$TC_IFACE" 2>/dev/null | grep -q "htb" && return 0 || return 1
}

# -- Inicializar tc --
init_tc() {
    detect_interface
    if is_tc_active; then
        return 0
    fi

    # Crear qdisc raiz
    tc qdisc add dev "$TC_IFACE" root handle 1: htb default 999 2>/dev/null
    # Clase por defecto (sin limite)
    tc class add dev "$TC_IFACE" parent 1: classid 1:999 htb rate 1000mbit ceil 1000mbit 2>/dev/null
    log_info "TC inicializado en $TC_IFACE"
}

# -- Aplicar limite a un usuario --
apply_limit() {
    local user="$1"
    local rate="$2"    # ej: 1mbit, 512kbit
    local ceil="$3"    # ej: 2mbit, 1mbit

    detect_interface

    # Obtener UID del usuario
    local uid=$(id -u "$user" 2>/dev/null)
    if [[ -z "$uid" ]]; then
        ui_error "Usuario no encontrado: $user"
        return 1
    fi

    # Usar UID como classid (con offset para evitar conflictos)
    local classid=$((uid + 10))

    init_tc

    # Crear clase para este usuario
    tc class add dev "$TC_IFACE" parent 1: classid "1:${classid}" htb rate "$rate" ceil "${ceil:-$rate}" 2>/dev/null
    tc class change dev "$TC_IFACE" parent 1: classid "1:${classid}" htb rate "$rate" ceil "${ceil:-$rate}" 2>/dev/null

    # Filtro por UID usando cgroup o iptables mark
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$uid" -j MARK --set-mark "$classid" 2>/dev/null
    tc filter add dev "$TC_IFACE" parent 1: protocol ip handle "$classid" fw flowid "1:${classid}" 2>/dev/null

    # Guardar config
    mkdir -p "${VPS_DIR}/bandwidth"
    echo "${user}:${rate}:${ceil:-$rate}" > "${VPS_DIR}/bandwidth/${user}.conf"

    ui_success "Limite aplicado a ${BGREEN}${user}${RST}: ${BCYAN}${rate}${RST} (max: ${ceil:-$rate})"
    log_info "Bandwidth limit: $user = $rate (ceil: ${ceil:-$rate})"
}

# -- Remover limite de un usuario --
remove_limit() {
    local user="$1"
    detect_interface

    local uid=$(id -u "$user" 2>/dev/null)
    if [[ -z "$uid" ]]; then
        ui_error "Usuario no encontrado: $user"
        return 1
    fi

    local classid=$((uid + 10))

    tc class del dev "$TC_IFACE" classid "1:${classid}" 2>/dev/null
    iptables -t mangle -D OUTPUT -m owner --uid-owner "$uid" -j MARK --set-mark "$classid" 2>/dev/null
    tc filter del dev "$TC_IFACE" parent 1: handle "$classid" fw 2>/dev/null

    rm -f "${VPS_DIR}/bandwidth/${user}.conf" 2>/dev/null

    ui_success "Limite removido para ${BGREEN}${user}${RST}"
}

# -- Listar limites activos --
list_limits() {
    echo -e "  ${BWHITE}USUARIO         VELOCIDAD       MAXIMO${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..50})${RST}"

    local count=0
    if [[ -d "${VPS_DIR}/bandwidth" ]]; then
        for conf in "${VPS_DIR}/bandwidth"/*.conf; do
            [[ -f "$conf" ]] || continue
            IFS=':' read -r user rate ceil < "$conf"
            printf "  ${BGREEN}%-15s${RST} ${BCYAN}%-15s${RST} ${BYELLOW}%s${RST}\n" "$user" "$rate" "$ceil"
            (( count++ ))
        done
    fi

    if (( count == 0 )); then
        echo -e "  ${BYELLOW}No hay limites configurados${RST}"
    fi
    echo -e "\n  ${BWHITE}Total: ${BGREEN}${count}${RST} usuarios limitados"
}

# -- Limite global --
apply_global_limit() {
    local rate="$1"
    detect_interface
    init_tc

    tc class change dev "$TC_IFACE" parent 1: classid 1:999 htb rate "$rate" ceil "$rate" 2>/dev/null
    echo "global:${rate}:${rate}" > "${VPS_DIR}/bandwidth/global.conf"
    ui_success "Limite global: ${BGREEN}${rate}${RST}"
}

# -- Menu --
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}     LIMITADOR DE ANCHO DE BANDA${RST}"
    ui_bar

    detect_interface
    echo -e "  ${BWHITE}Interfaz:${RST} ${BCYAN}${TC_IFACE:-no detectada}${RST}"
    local tc_st="OFF"
    is_tc_active && tc_st="ON"
    echo -e "  ${BWHITE}TC Status:${RST} $([ "$tc_st" = "ON" ] && echo -e "${STATUS_ON}" || echo -e "${STATUS_OFF}")"
    ui_bar

    ui_menu_item 1 "Limitar usuario"
    ui_menu_item 2 "Remover limite de usuario"
    ui_menu_item 3 "Limite global (todos)"
    ui_menu_item 4 "Ver limites activos"
    ui_menu_item 5 "Desactivar todo (limpiar tc)"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 5)

    case "$sel" in
        1)
            ui_bar
            local user rate ceil
            user=$(ui_input "Nombre del usuario" "^[a-zA-Z0-9_]+$")
            echo -e "  ${BWHITE}Formatos: 512kbit, 1mbit, 5mbit, 10mbit${RST}"
            rate=$(ui_input "Velocidad garantizada" "^[0-9]+[km]bit$")
            ceil=$(ui_input "Velocidad maxima (ceil)" "^[0-9]+[km]bit$" "$rate")
            apply_limit "$user" "$rate" "$ceil"
            ;;
        2)
            ui_bar
            local user
            user=$(ui_input "Usuario a remover limite" "^[a-zA-Z0-9_]+$")
            remove_limit "$user"
            ;;
        3)
            ui_bar
            echo -e "  ${BWHITE}Formatos: 10mbit, 50mbit, 100mbit${RST}"
            local rate
            rate=$(ui_input "Limite global" "^[0-9]+[km]bit$")
            apply_global_limit "$rate"
            ;;
        4)
            ui_bar
            list_limits
            ui_bar
            ;;
        5)
            detect_interface
            tc qdisc del dev "$TC_IFACE" root 2>/dev/null
            iptables -t mangle -F 2>/dev/null
            rm -rf "${VPS_DIR}/bandwidth" 2>/dev/null
            ui_success "TC desactivado completamente"
            ui_bar
            ;;
        0) return ;;
    esac
}

main
