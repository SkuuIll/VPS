#!/bin/bash
# ============================================================
# VPS-MX — Optimizadores Básicos
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

# ── TCP Speed ──
toggle_tcp_speed() {
    local marker="#VPS-MX-TCP"

    if grep -q "^${marker}" /etc/sysctl.conf 2>/dev/null; then
        # Desactivar
        ui_info "TCP Speed está activo. ¿Desactivar?"
        ui_bar
        if ui_confirm "¿Desactivar TCP Speed?"; then
            sed -i "/${marker}/,/^$/d" /etc/sysctl.conf
            sysctl -p /etc/sysctl.conf > /dev/null 2>&1
            ui_success "TCP Speed desactivado"
        fi
    else
        # Activar
        ui_info "TCP Speed no está activo. ¿Activar?"
        ui_bar
        if ui_confirm "¿Activar TCP Speed?"; then
            backup_file /etc/sysctl.conf
            cat >> /etc/sysctl.conf << EOF
${marker}
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0

EOF
            sysctl -p /etc/sysctl.conf > /dev/null 2>&1
            ui_success "TCP Speed activado"
        fi
    fi
    ui_bar
}

# ── Cache Squid ──
toggle_squid_cache() {
    local squid_conf=""
    [[ -f /etc/squid/squid.conf ]] && squid_conf="/etc/squid/squid.conf"
    [[ -f /etc/squid3/squid.conf ]] && squid_conf="/etc/squid3/squid.conf"

    if [[ -z "$squid_conf" ]]; then
        ui_error "Squid no está instalado"
        return 1
    fi

    local marker="#CACHE DO SQUID"

    if grep -q "^${marker}" "$squid_conf" 2>/dev/null; then
        ui_info "Cache Squid activo. ¿Eliminar?"
        ui_bar
        if ui_confirm "¿Eliminar cache?" && [[ -f "${squid_conf}.bakk" ]]; then
            mv -f "${squid_conf}.bakk" "$squid_conf"
            service_ctl restart squid 2>/dev/null
            service_ctl restart squid3 2>/dev/null
            ui_success "Cache Squid removido"
        fi
    else
        ui_info "Aplicando Cache Squid..."
        backup_file "$squid_conf"
        cp "$squid_conf" "${squid_conf}.bakk"

        local cache_config="${marker}
cache_mem 200 MB
maximum_object_size_in_memory 32 KB
maximum_object_size 1024 MB
minimum_object_size 0 KB
cache_swap_low 90
cache_swap_high 95"

        if [[ "$squid_conf" == "/etc/squid/squid.conf" ]]; then
            cache_config+="
cache_dir ufs /var/spool/squid 100 16 256
access_log /var/log/squid/access.log squid"
        else
            cache_config+="
cache_dir ufs /var/spool/squid3 100 16 256
access_log /var/log/squid3/access.log squid"
        fi

        sed -i '/cache deny all/d' "$squid_conf"
        echo -e "$cache_config" | cat - "$squid_conf" > /tmp/squid_tmp && mv /tmp/squid_tmp "$squid_conf"

        service_ctl restart squid 2>/dev/null
        service_ctl restart squid3 2>/dev/null
        ui_success "Cache Squid aplicado"
    fi
    ui_bar
}

# ── Limpiar RAM ──
clean_ram() {
    run_with_spinner "Limpiando RAM..." "sync && sysctl -w vm.drop_caches=3"
    ui_success "RAM limpiada"
    ui_bar
}

# ── Limpiar paquetes obsoletos ──
clean_packages() {
    ui_step "Buscando paquetes obsoletos..."
    local count
    count=$(dpkg -l 2>/dev/null | grep -c '^rc' || echo "0")
    echo -e "  ${BWHITE}Encontrados: ${BCYAN}${count}${RST} paquetes obsoletos"

    if (( count > 0 )); then
        run_with_spinner "Limpiando paquetes..." "dpkg -l | grep '^rc' | cut -d ' ' -f 3 | xargs dpkg --purge"
        ui_success "Paquetes obsoletos eliminados"
    else
        ui_info "No hay paquetes obsoletos"
    fi
    ui_bar
}

# ── Reset iptables ──
reset_iptables() {
    ui_warn "Esto reiniciará TODAS las reglas de iptables"
    ui_bar
    if ui_confirm "¿Está seguro?" "n"; then
        run_with_spinner "Reiniciando iptables..." \
            "iptables -F && iptables -X && iptables -t nat -F && iptables -t nat -X && iptables -t mangle -F && iptables -t mangle -X && iptables -t raw -F && iptables -t raw -X && iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT && iptables -P OUTPUT ACCEPT"
        ui_success "iptables reiniciadas"
    fi
    ui_bar
}

# ── Status indicators ──
get_tcp_status() {
    grep -q "^#VPS-MX-TCP" /etc/sysctl.conf 2>/dev/null && echo -e "${STATUS_ON}" || echo -e "${STATUS_OFF}"
}

get_squid_cache_status() {
    local conf=""
    [[ -f /etc/squid/squid.conf ]] && conf="/etc/squid/squid.conf"
    [[ -f /etc/squid3/squid.conf ]] && conf="/etc/squid3/squid.conf"
    [[ -n "$conf" ]] && grep -q "^#CACHE DO SQUID" "$conf" 2>/dev/null && echo -e "${STATUS_ON}" || echo -e "${STATUS_OFF}"
}

# ── Menú principal ──
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}            OPTIMIZADORES BÁSICOS${RST}"
    ui_bar

    ui_menu_item 1 "TCP Speed" "$(get_tcp_status)"
    ui_menu_item 2 "Cache Squid" "$(get_squid_cache_status)"
    ui_menu_item 3 "Limpiar RAM"
    ui_menu_item 4 "Limpiar Paquetes Obsoletos"
    ui_menu_item 5 "Reset iptables"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 5)

    case "$sel" in
        1) toggle_tcp_speed ;;
        2) toggle_squid_cache ;;
        3) clean_ram ;;
        4) clean_packages ;;
        5) reset_iptables ;;
        0) return ;;
    esac
}

main