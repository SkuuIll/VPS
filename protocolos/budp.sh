#!/bin/bash
# ============================================================
# VPS-MX — BadVPN UDPGW (Activador/Desactivador)
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

BADVPN_BIN="/usr/bin/badvpn-udpgw"
BADVPN_PORT="${1:-7300}"
BADVPN_SERVICE="badvpn-udpgw"

# ── Verificar si badvpn está corriendo ──
is_badvpn_running() {
    pgrep -f "badvpn-udpgw" &>/dev/null
}

# ── Instalar binario si no existe ──
ensure_binary() {
    if [[ ! -f "$BADVPN_BIN" ]]; then
        ui_step "Descargando badvpn-udpgw..."
        local arch=$(uname -m)
        # Intentar compilar o descargar según arquitectura
        if has_command apt-get; then
            apt-get install -y cmake build-essential &>/dev/null || true
        fi
        # Fallback: descargar binario precompilado
        download_file "https://github.com/nicholasgasior/badvpn/releases/latest/download/badvpn-udpgw" "$BADVPN_BIN" || {
            ui_error "No se pudo descargar badvpn-udpgw"
            return 1
        }
        chmod 755 "$BADVPN_BIN"
    fi
}

# ── Activar con systemd ──
start_badvpn() {
    ensure_binary || return 1

    # Intentar systemd primero
    if [[ -f /etc/systemd/system/${BADVPN_SERVICE}.service ]]; then
        systemctl start "$BADVPN_SERVICE" 2>/dev/null
        systemctl enable "$BADVPN_SERVICE" 2>/dev/null
    else
        # Fallback: crear servicio o usar screen
        if has_command systemctl; then
            cat > /etc/systemd/system/${BADVPN_SERVICE}.service << EOF
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
Type=simple
ExecStart=${BADVPN_BIN} --listen-addr 127.0.0.1:${BADVPN_PORT} --max-clients 1000 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl start "$BADVPN_SERVICE"
            systemctl enable "$BADVPN_SERVICE"
        else
            screen -dmS badvpn "$BADVPN_BIN" --listen-addr "127.0.0.1:${BADVPN_PORT}" --max-clients 1000 --max-connections-for-client 10
        fi
    fi

    sleep 1
    if is_badvpn_running; then
        ui_success "BadVPN UDPGW activado en puerto ${BGREEN}${BADVPN_PORT}${RST}"
    else
        ui_error "No se pudo iniciar BadVPN"
    fi
}

# ── Desactivar ──
stop_badvpn() {
    systemctl stop "$BADVPN_SERVICE" 2>/dev/null
    systemctl disable "$BADVPN_SERVICE" 2>/dev/null
    kill_by_name "badvpn-udpgw" 2>/dev/null

    sleep 1
    if ! is_badvpn_running; then
        ui_success "BadVPN UDPGW desactivado"
    else
        ui_error "No se pudo detener BadVPN"
    fi
}

# ── Menú ──
main() {
    ui_clear
    ui_bar
    ui_title_small

    if is_badvpn_running; then
        echo -e "${THEME_HEADER}        DESACTIVAR BADVPN (UDP:${BADVPN_PORT})${RST}"
        ui_bar
        echo -e "  ${BWHITE}Estado:${RST} ${STATUS_ON}"
        ui_bar
        if ui_confirm "¿Desactivar BadVPN?"; then
            stop_badvpn
        fi
    else
        echo -e "${THEME_HEADER}         ACTIVAR BADVPN (UDP:${BADVPN_PORT})${RST}"
        ui_bar
        echo -e "  ${BWHITE}Estado:${RST} ${STATUS_OFF}"
        ui_bar

        local port
        port=$(ui_input "Puerto UDP" "^[0-9]+$" "${BADVPN_PORT}")
        BADVPN_PORT="$port"

        start_badvpn
    fi
    ui_bar
}

main