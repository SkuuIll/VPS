#!/bin/bash
# ============================================================
# VPS -- Dashboard de Estadisticas
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

# -- Calcular trafico de red --
get_traffic() {
    local iface
    iface=$(ip route | grep default | awk '{print $5}' | head -1)

    if [[ -z "$iface" ]]; then
        echo "N/A"
        return
    fi

    local rx_bytes tx_bytes
    rx_bytes=$(cat "/sys/class/net/${iface}/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx_bytes=$(cat "/sys/class/net/${iface}/statistics/tx_bytes" 2>/dev/null || echo 0)

    local rx_gb=$(echo "scale=2; $rx_bytes / 1073741824" | bc 2>/dev/null || echo "N/A")
    local tx_gb=$(echo "scale=2; $tx_bytes / 1073741824" | bc 2>/dev/null || echo "N/A")
    local total_gb=$(echo "scale=2; ($rx_bytes + $tx_bytes) / 1073741824" | bc 2>/dev/null || echo "N/A")

    echo "${rx_gb}|${tx_gb}|${total_gb}"
}

# -- Barra visual de porcentaje --
progress_bar() {
    local pct="$1"
    local width="${2:-30}"
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color

    if (( pct >= 90 )); then color="$BRED"
    elif (( pct >= 70 )); then color="$BYELLOW"
    else color="$BGREEN"; fi

    printf "${BWHITE}[${RST}"
    printf "${color}%0.s#${RST}" $(seq 1 $filled) 2>/dev/null
    printf "${DARKGRAY}%0.s-${RST}" $(seq 1 $empty) 2>/dev/null
    printf "${BWHITE}]${RST} ${color}%3d%%${RST}" "$pct"
}

# -- Contar usuarios por estado --
count_users_by_status() {
    local active=0 expired=0 blocked=0

    if [[ -d "${VPS_DIR}/expires" ]]; then
        for conf in "${VPS_DIR}/expires"/*.conf; do
            [[ -f "$conf" ]] || continue
            local estado=""
            source "$conf"
            case "$estado" in
                activo) (( active++ )) ;;
                bloqueado) (( blocked++ )) ;;
                *) (( expired++ )) ;;
            esac
        done
    fi

    echo "${active}|${expired}|${blocked}"
}

# -- Dashboard principal --
show_dashboard() {
    ui_clear
    echo ""
    echo -e "${BCYAN}  ██╗   ██╗██████╗ ███████╗    ███╗   ███╗██╗  ██╗${RST}"
    echo -e "${BCYAN}  ██║   ██║██╔══██╗██╔════╝    ████╗ ████║╚██╗██╔╝${RST}"
    echo -e "${BCYAN}  ██║   ██║██████╔╝███████╗    ██╔████╔██║ ╚███╔╝ ${RST}"
    echo -e "${BCYAN}  ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║ ██╔██╗ ${RST}"
    echo -e "${BCYAN}   ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║██╔╝ ██╗${RST}"
    echo -e "${BCYAN}    ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝${RST}"
    echo -e "${BYELLOW}  ============ DASHBOARD v${VPS_VERSION} ============${RST}"
    echo ""
    ui_bar

    # -- Servidor --
    echo -e "  ${BWHITE}SERVIDOR${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..55})${RST}"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "IP Publica:" "$(get_ip)"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "IP Local:" "$(get_local_ip)"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "Hostname:" "$(hostname)"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "OS:" "$(get_os)"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "Kernel:" "$(uname -r)"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "Uptime:" "$(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | awk -F',' '{print $1}')"
    echo ""

    # -- CPU --
    echo -e "  ${BWHITE}CPU${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..55})${RST}"
    local cpu_pct
    cpu_pct=$(top -bn1 2>/dev/null | grep 'Cpu(s)' | awk '{printf "%.0f", $2 + $4}')
    cpu_pct=${cpu_pct:-0}
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST} x${BGREEN}%s${RST} nucleos\n" "Procesador:" "$(get_sysinfo cpu_model | cut -c1-30)" "$(nproc)"
    printf "  ${BRED}%-18s${RST} " "Uso:"
    progress_bar "$cpu_pct"
    echo ""

    # -- RAM --
    echo ""
    echo -e "  ${BWHITE}MEMORIA RAM${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..55})${RST}"
    local ram_total ram_used ram_pct
    ram_total=$(free | awk '/Mem:/{print $2}')
    ram_used=$(free | awk '/Mem:/{print $3}')
    ram_pct=$(( ram_used * 100 / ram_total ))
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST} / ${BGREEN}%s${RST}\n" "Uso:" "$(get_sysinfo ram_used)" "$(get_sysinfo ram_total)"
    printf "  ${BRED}%-18s${RST} " "Porcentaje:"
    progress_bar "$ram_pct"
    echo ""

    # -- Disco --
    echo ""
    echo -e "  ${BWHITE}DISCO${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..55})${RST}"
    local disk_total disk_used disk_pct
    disk_total=$(df -h / | awk 'NR==2{print $2}')
    disk_used=$(df -h / | awk 'NR==2{print $3}')
    disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST} / ${BGREEN}%s${RST}\n" "Uso:" "$disk_used" "$disk_total"
    printf "  ${BRED}%-18s${RST} " "Porcentaje:"
    progress_bar "$disk_pct"
    echo ""

    # -- Trafico --
    echo ""
    echo -e "  ${BWHITE}TRAFICO DE RED${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..55})${RST}"
    local iface traffic rx tx total
    iface=$(ip route | grep default | awk '{print $5}' | head -1)
    traffic=$(get_traffic)
    IFS='|' read -r rx tx total <<< "$traffic"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "Interfaz:" "${iface:-N/A}"
    printf "  ${BRED}%-18s${RST} ${BCYAN}%s GB${RST}\n" "Descarga (RX):" "$rx"
    printf "  ${BRED}%-18s${RST} ${BCYAN}%s GB${RST}\n" "Subida (TX):" "$tx"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s GB${RST}\n" "Total:" "$total"

    # -- Servicios --
    echo ""
    echo -e "  ${BWHITE}SERVICIOS${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..55})${RST}"
    local services=(sshd dropbear stunnel4 squid openvpn v2ray badvpn-udpgw)
    for svc in "${services[@]}"; do
        local st
        if is_running "$svc"; then
            st="${BGREEN}ACTIVO${RST}"
        else
            st="${DARKGRAY}INACTIVO${RST}"
        fi
        printf "  ${BRED}%-18s${RST} %b\n" "${svc}:" "$st"
    done

    # -- Usuarios --
    echo ""
    echo -e "  ${BWHITE}USUARIOS${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..55})${RST}"
    local ssh_reg=$(( $(count_ssh_users) - 2 ))
    (( ssh_reg < 0 )) && ssh_reg=0
    local connected=$(who 2>/dev/null | wc -l)
    local user_stats
    user_stats=$(count_users_by_status)
    IFS='|' read -r u_active u_expired u_blocked <<< "$user_stats"

    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "Registrados:" "$ssh_reg"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST}\n" "Conectados:" "$connected"
    printf "  ${BRED}%-18s${RST} ${BGREEN}%s${RST} activos | ${BRED}%s${RST} expirados | ${BYELLOW}%s${RST} bloqueados\n" "Con expiracion:" "$u_active" "$u_expired" "$u_blocked"

    echo ""
    ui_bar
    echo -e "  ${DARKGRAY}Dashboard generado: $(date '+%H:%M:%S %d/%m/%Y')${RST}"
    ui_bar
}

# -- Modo auto-refresh --
dashboard_live() {
    while true; do
        show_dashboard
        echo -e "  ${DARKGRAY}Auto-refresh cada 10s | CTRL+C para salir${RST}"
        sleep 10
    done
}

# -- Menu --
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}          DASHBOARD${RST}"
    ui_bar

    ui_menu_item 1 "Ver Dashboard completo"
    ui_menu_item 2 "Dashboard en vivo (auto-refresh)"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 2)

    case "$sel" in
        1) show_dashboard; ui_pause ;;
        2) dashboard_live ;;
        0) return ;;
    esac
}

main
