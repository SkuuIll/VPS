#!/bin/bash
# ============================================================
# VPS-MX — Firewall / Bloqueo BitTorrent
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

# ── Verificar si el bloqueo BT está activo ──
is_bt_blocked() {
    iptables -L -n 2>/dev/null | grep -qi "torrent\|bittorrent" && return 0 || return 1
}

# ── Bloquear BitTorrent ──
block_bt() {
    ui_step "Aplicando reglas de bloqueo BitTorrent..."

    # Bloquear puertos comunes de BitTorrent
    local bt_ports="6881:6999"

    iptables -A FORWARD -m string --string "BitTorrent" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -A FORWARD -m string --string "BitTorrent protocol" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -A FORWARD -m string --string ".torrent" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -A FORWARD -m string --string "announce.php?passkey=" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -A FORWARD -m string --string "torrent" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -A FORWARD -m string --string "peer_id=" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -A FORWARD -p tcp --dport ${bt_ports} -j DROP 2>/dev/null
    iptables -A FORWARD -p udp --dport ${bt_ports} -j DROP 2>/dev/null

    # Guardar reglas
    if has_command iptables-save; then
        iptables-save > /etc/iptables.rules 2>/dev/null
    fi

    ui_success "BitTorrent bloqueado"
    ui_bar
}

# ── Desbloquear BitTorrent ──
unblock_bt() {
    ui_step "Removiendo reglas de bloqueo BitTorrent..."

    iptables -D FORWARD -m string --string "BitTorrent" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -D FORWARD -m string --string "BitTorrent protocol" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -D FORWARD -m string --string ".torrent" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -D FORWARD -m string --string "announce.php?passkey=" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -D FORWARD -m string --string "torrent" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -D FORWARD -m string --string "peer_id=" --algo bm --to 65535 -j DROP 2>/dev/null
    iptables -D FORWARD -p tcp --dport 6881:6999 -j DROP 2>/dev/null
    iptables -D FORWARD -p udp --dport 6881:6999 -j DROP 2>/dev/null

    if has_command iptables-save; then
        iptables-save > /etc/iptables.rules 2>/dev/null
    fi

    ui_success "Bloqueo BitTorrent removido"
    ui_bar
}

# ── Bloquear puertos personalizados ──
block_custom_port() {
    local port
    port=$(ui_input "Puerto a bloquear" "^[0-9]+$")
    local proto
    proto=$(ui_input "Protocolo (tcp/udp/both)" "^(tcp|udp|both)$" "both")

    if [[ "$proto" == "both" ]]; then
        iptables -A INPUT -p tcp --dport "$port" -j DROP 2>/dev/null
        iptables -A INPUT -p udp --dport "$port" -j DROP 2>/dev/null
    else
        iptables -A INPUT -p "$proto" --dport "$port" -j DROP 2>/dev/null
    fi

    iptables-save > /etc/iptables.rules 2>/dev/null
    ui_success "Puerto ${port}/${proto} bloqueado"
    ui_bar
}

# ── Mostrar reglas activas ──
show_rules() {
    ui_step "Reglas de firewall activas:"
    ui_bar
    iptables -L -n --line-numbers 2>/dev/null | head -50
    ui_bar
}

# ── Menú principal ──
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}           FIREWALL / BLOQUEO${RST}"
    ui_bar

    local bt_status
    is_bt_blocked && bt_status="${STATUS_ON}" || bt_status="${STATUS_OFF}"

    ui_menu_item 1 "Bloquear BitTorrent" "$bt_status"
    ui_menu_item 2 "Desbloquear BitTorrent"
    ui_menu_item 3 "Bloquear Puerto Personalizado"
    ui_menu_item 4 "Ver Reglas del Firewall"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 4)

    case "$sel" in
        1) block_bt ;;
        2) unblock_bt ;;
        3) block_custom_port ;;
        4) show_rules ;;
        0) return ;;
    esac
}

main