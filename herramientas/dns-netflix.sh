#!/bin/bash
# ============================================================
# VPS — DNS Netflix
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}           DNS - NETFLIX / STREAMING${RST}"
    ui_bar

    ui_info "Configura DNS para desbloquear contenido geo-restringido"
    ui_bar

    ui_menu_item 1 "Google DNS (8.8.8.8 / 8.8.4.4)"
    ui_menu_item 2 "Cloudflare DNS (1.1.1.1 / 1.0.0.1)"
    ui_menu_item 3 "OpenDNS (208.67.222.222)"
    ui_menu_item 4 "DNS personalizado"
    ui_menu_item 5 "Restaurar DNS original"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 5)

    local dns1="" dns2=""

    case "$sel" in
        1) dns1="8.8.8.8";     dns2="8.8.4.4" ;;
        2) dns1="1.1.1.1";     dns2="1.0.0.1" ;;
        3) dns1="208.67.222.222"; dns2="208.67.220.220" ;;
        4)
            dns1=$(ui_input "DNS primario" "^[0-9.]+$")
            dns2=$(ui_input "DNS secundario" "^[0-9.]+$")
            ;;
        5)
            if [[ -f /etc/resolv.conf.bak ]]; then
                mv -f /etc/resolv.conf.bak /etc/resolv.conf
                ui_success "DNS restaurado al original"
            else
                ui_warn "No hay backup del DNS original"
            fi
            ui_bar
            return
            ;;
        0) return ;;
    esac

    if [[ -n "$dns1" ]]; then
        backup_file /etc/resolv.conf
        cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null

        cat > /etc/resolv.conf << EOF
nameserver ${dns1}
nameserver ${dns2}
EOF

        # Prevenir que se sobreescriba
        chattr +i /etc/resolv.conf 2>/dev/null || true

        ui_bar
        ui_success "DNS configurado"
        echo -e "  ${BWHITE}Primario:${RST}   ${BGREEN}${dns1}${RST}"
        echo -e "  ${BWHITE}Secundario:${RST} ${BGREEN}${dns2}${RST}"
    fi
    ui_bar
}

main