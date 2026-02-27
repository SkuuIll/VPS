#!/bin/bash
# ============================================================
# VPS — Prueba de Velocidad (Speedtest)
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh" 2>/dev/null || source "/etc/VPS/lib/config.sh" 2>/dev/null || true
check_root

main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}             PRUEBA DE VELOCIDAD${RST}"
    ui_bar

    # Asegurar que existe speedtest-cli
    if [[ ! -f /usr/local/bin/speedtest-cli ]]; then
        run_with_spinner "Instalando Speedtest CLI..." "wget -qO /usr/local/bin/speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py && chmod +x /usr/local/bin/speedtest-cli"
        if [[ ! -f /usr/local/bin/speedtest-cli ]]; then
            ui_error "Fallo al instalar Speedtest CLI."
            ui_pause
            return
        fi
    fi

    echo -e " ${BCYAN}ℹ${RST} Buscando el mejor servidor (puede demorar)..."
    echo ""
    
    # Ejecutar speedtest visualmente
    /usr/local/bin/speedtest-cli --simple --bytes
    
    echo ""
    ui_bar
}

main
