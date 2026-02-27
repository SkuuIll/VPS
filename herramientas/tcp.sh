#!/bin/bash
# ============================================================
# VPS — Aceleración TCP (BBR)
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh" 2>/dev/null || source "/etc/VPS/lib/config.sh" 2>/dev/null || true
check_root

# ── Habilitar BBR nativo ──
enable_bbr() {
    ui_step "Verificando soporte de BBR en el Kernel..."
    
    local kernel_ver=$(uname -r | cut -d. -f1,2)
    local min_ver="4.9"
    
    if dpkg --compare-versions "$kernel_ver" "lt" "$min_ver"; then
        ui_error "Tu Kernel ($kernel_ver) no soporta BBR nativo. Se requiere 4.9 o superior."
        ui_pause
        return
    fi
    
    ui_step "Aplicando optimizaciones TCP BBR..."
    backup_file /etc/sysctl.conf
    
    # Remover viejos
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    
    # Agregar nuevos
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    
    sysctl -p > /dev/null 2>&1
    
    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        ui_success "Aceleración BBR habilitada correctamente."
        echo -e " ${BCYAN}ℹ${RST} El algoritmo TCP BBR está funcionando y mejorará tu velocidad."
    else
        ui_error "Error al aplicar BBR."
    fi
    ui_pause
}

# ── Deshabilitar BBR ──
disable_bbr() {
    ui_step "Deshabilitando optimizaciones BBR..."
    
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    
    sysctl -p > /dev/null 2>&1
    ui_success "Optimizaciones de red restauradas por defecto."
    ui_pause
}

# ── Optimizaciones extra ──
optimize_sys() {
    ui_step "Aplicando parámetros para alta carga (High Load)..."
    backup_file /etc/sysctl.conf
    
    local keys=(
        "fs.file-max"
        "fs.inotify.max_user_instances"
        "net.ipv4.tcp_syncookies"
        "net.ipv4.tcp_tw_reuse"
        "net.core.somaxconn"
        "net.core.netdev_max_backlog"
    )
    for k in "${keys[@]}"; do sed -i "/^$k/d" /etc/sysctl.conf; done
    
    cat >> /etc/sysctl.conf << EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
EOF

    cat > /etc/security/limits.d/99-vps.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
EOF

    sysctl -p > /dev/null 2>&1
    ui_success "Sistema optimizado para alto tráfico y conexiones."
    ui_pause
}

check_bbr_status() {
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    
    if [[ "$qdisc" == "fq" ]] && [[ "$cc" == *"bbr"* ]]; then
        return 0
    fi
    return 1
}

# ── Menú principal ──
main() {
    while true; do
        ui_clear
        ui_bar
        ui_title_small
        echo -e "${THEME_HEADER}          ACELERADOR TCP (BBR)${RST}"
        ui_bar
        
        local stat
        check_bbr_status && stat="${STATUS_ON}" || stat="${STATUS_OFF}"
        
        echo -e " ${BCYAN}ℹ${RST} BBR optimiza la congestión de red haciendo"
        echo -e "   que tus proxys y túneles vayan más rápido."
        ui_bar
        
        ui_menu_item 1 "Habilitar TCP BBR (Recomendado)" "$stat"
        ui_menu_item 2 "Deshabilitar Otimizacion BBR"
        ui_menu_item 3 "Optimizar sistema para Alto Tráfico"
        ui_bar
        ui_menu_back 0
        ui_bar
        
        local sel
        sel=$(ui_select 3)
        case "$sel" in
            1) enable_bbr ;;
            2) disable_bbr ;;
            3) optimize_sys ;;
            0) return ;;
        esac
    done
}

main
