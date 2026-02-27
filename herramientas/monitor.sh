#!/bin/bash
# ============================================================
# VPS-MX -- Monitor de Usuarios en Tiempo Real
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

# -- Usuarios SSH conectados --
get_ssh_connections() {
    # who: muestra usuarios logueados
    # ss: muestra conexiones TCP establecidas a SSH
    echo -e "${BWHITE}  USUARIO        IP ORIGEN           CONECTADO DESDE      PID${RST}"
    echo -e "${BYELLOW}  $(printf '%0.s-' {1..65})${RST}"

    # Obtener conexiones SSH activas
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local user=$(echo "$line" | awk '{print $1}')
        local tty=$(echo "$line" | awk '{print $2}')
        local from=$(echo "$line" | awk '{print $5}' | tr -d '()')
        local since=$(echo "$line" | awk '{print $3, $4}')

        # Obtener PID
        local pid=$(ps aux | grep "sshd.*${user}@" | grep -v grep | awk '{print $2}' | head -1)

        [[ "$user" == "root" && -z "$from" ]] && continue

        printf "  ${BGREEN}%-15s${RST} ${BCYAN}%-20s${RST} ${BWHITE}%-20s${RST} ${BYELLOW}%s${RST}\n" \
            "$user" "${from:-local}" "$since" "${pid:-N/A}"
        (( count++ ))
    done <<< "$(who 2>/dev/null)"

    if (( count == 0 )); then
        echo -e "  ${BYELLOW}No hay usuarios SSH conectados${RST}"
    fi
    echo ""
    echo -e "  ${BWHITE}Total conectados: ${BGREEN}${count}${RST}"
}

# -- Conexiones Dropbear --
get_dropbear_connections() {
    local count=0
    echo -e "\n${BWHITE}  CONEXIONES DROPBEAR${RST}"
    echo -e "${BYELLOW}  $(printf '%0.s-' {1..65})${RST}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local pid=$(echo "$line" | awk '{print $2}')
        local user=$(echo "$line" | awk '{print $1}')
        printf "  ${BGREEN}%-15s${RST} PID: ${BCYAN}%s${RST}\n" "$user" "$pid"
        (( count++ ))
    done <<< "$(ps aux | grep 'dropbear' | grep -v grep | grep -v '/usr/sbin/dropbear' 2>/dev/null)"

    if (( count == 0 )); then
        echo -e "  ${BYELLOW}No hay conexiones Dropbear${RST}"
    fi
}

# -- Conexiones OpenVPN --
get_openvpn_connections() {
    local status_file="/etc/openvpn/openvpn-status.log"
    echo -e "\n${BWHITE}  CONEXIONES OPENVPN${RST}"
    echo -e "${BYELLOW}  $(printf '%0.s-' {1..65})${RST}"

    if [[ -f "$status_file" ]]; then
        local count=0
        local in_clients=false
        while IFS= read -r line; do
            if echo "$line" | grep -q "Common Name"; then
                in_clients=true
                continue
            fi
            if echo "$line" | grep -q "ROUTING TABLE"; then
                in_clients=false
                continue
            fi
            if $in_clients && [[ -n "$line" ]]; then
                local cn=$(echo "$line" | cut -d',' -f1)
                local ip=$(echo "$line" | cut -d',' -f2)
                local since=$(echo "$line" | cut -d',' -f5)
                printf "  ${BGREEN}%-15s${RST} ${BCYAN}%-20s${RST} ${BWHITE}%s${RST}\n" "$cn" "$ip" "$since"
                (( count++ ))
            fi
        done < "$status_file"
        echo -e "  ${BWHITE}Total: ${BGREEN}${count}${RST}"
    else
        echo -e "  ${BYELLOW}OpenVPN no activo o sin log de status${RST}"
    fi
}

# -- Conexiones por puerto (resumen) --
get_connection_summary() {
    echo -e "\n${BWHITE}  RESUMEN DE CONEXIONES ACTIVAS${RST}"
    echo -e "${BYELLOW}  $(printf '%0.s-' {1..65})${RST}"

    local total_ssh=$(ss -tnp 2>/dev/null | grep -c ':22\b' || echo 0)
    local total_443=$(ss -tnp 2>/dev/null | grep -c ':443\b' || echo 0)
    local total_squid=$(ss -tnp 2>/dev/null | grep -c 'squid' || echo 0)
    local total_vpn=$(ss -tnp 2>/dev/null | grep -c 'openvpn' || echo 0)
    local total_est=$(ss -tn 2>/dev/null | grep -c ESTAB || echo 0)

    printf "  ${BRED}SSH (22):${RST}      ${BGREEN}%s${RST} conexiones\n" "$total_ssh"
    printf "  ${BRED}SSL (443):${RST}     ${BGREEN}%s${RST} conexiones\n" "$total_443"
    printf "  ${BRED}Squid:${RST}         ${BGREEN}%s${RST} conexiones\n" "$total_squid"
    printf "  ${BRED}OpenVPN:${RST}       ${BGREEN}%s${RST} conexiones\n" "$total_vpn"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..40})${RST}"
    printf "  ${BWHITE}TOTAL:${RST}         ${BGREEN}%s${RST} conexiones establecidas\n" "$total_est"
}

# -- Modo auto-refresh --
monitor_live() {
    local interval="${1:-5}"
    ui_info "Monitor en vivo (actualiza cada ${interval}s). CTRL+C para salir."
    ui_bar

    while true; do
        ui_clear
        ui_bar
        ui_title_small
        echo -e "${THEME_HEADER}        MONITOR EN TIEMPO REAL${RST}"
        echo -e "  ${DARKGRAY}Actualizado: $(date '+%H:%M:%S')  |  Intervalo: ${interval}s${RST}"
        ui_bar
        get_ssh_connections
        get_dropbear_connections
        get_connection_summary
        ui_bar
        echo -e "  ${DARKGRAY}CTRL+C para salir${RST}"
        sleep "$interval"
    done
}

# -- Menu --
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}       MONITOR DE USUARIOS${RST}"
    ui_bar

    ui_menu_item 1 "Ver usuarios conectados ahora"
    ui_menu_item 2 "Monitor en tiempo real (auto-refresh)"
    ui_menu_item 3 "Conexiones OpenVPN"
    ui_menu_item 4 "Resumen de conexiones"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 4)

    case "$sel" in
        1)
            ui_bar
            get_ssh_connections
            get_dropbear_connections
            ui_bar
            ;;
        2) monitor_live 5 ;;
        3)
            ui_bar
            get_openvpn_connections
            ui_bar
            ;;
        4)
            ui_bar
            get_connection_summary
            ui_bar
            ;;
        0) return ;;
    esac
}

main
