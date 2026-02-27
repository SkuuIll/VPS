#!/bin/bash
# ============================================================
# VPS — Fail2Ban Protcción Anti-DDoS
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh" 2>/dev/null || source "/etc/VPS/lib/config.sh" 2>/dev/null || true
check_root

JAIL_FILE="/etc/fail2ban/jail.local"

install_fail2ban() {
    ui_step "Instalando Fail2Ban nativo..."
    
    # Aseguramos que existe el paquete
    run_with_spinner "Instalando paquetes via APT..." "apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install fail2ban -y"
    
    if ! command -v fail2ban-client &> /dev/null; then
        ui_error "Error instalando Fail2Ban desde los repositorios."
        return
    fi
    
    # Crear configuración básica
    ui_step "Generando reglas de protección..."
    cat > "$JAIL_FILE" << 'EOF'
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime  = 3600
findtime  = 600
maxretry = 5
banaction = iptables-multiport

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
maxretry = 3

[dropbear]
enabled = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 3

[squid]
enabled = true
port     =  80,443,3128,8080
logpath = /var/log/squid/access.log
maxretry = 5
EOF

    # Si apache2 está instalado, agregarlo tmb
    if sysctl -n dpkg &>/dev/null && dpkg -l | grep -q apache2; then
        cat >> "$JAIL_FILE" << 'EOF'

[apache-auth]
enabled = true
port     = http,https
logpath  = /var/log/apache2/*error.log
EOF
    fi

    # Reiniciar fail2ban
    run_with_spinner "Reiniciando servicio Fail2Ban..." "systemctl restart fail2ban && systemctl enable fail2ban"
    
    ui_success "Fail2Ban instalado y protegiendo SSH, Dropbear y Squid."
    ui_pause
}

remove_fail2ban() {
    if ! ui_confirm "¿Está seguro que desea eliminar Fail2Ban?"; then
        return
    fi
    
    run_with_spinner "Removiendo Fail2Ban..." "systemctl stop fail2ban; apt-get purge -y fail2ban; rm -rf /etc/fail2ban"
    ui_success "Fail2Ban ha sido eliminado del sistema."
    ui_pause
}

view_logs() {
    if [[ ! -f /var/log/fail2ban.log ]]; then
        ui_warn "No hay logs de Fail2Ban."
        ui_pause
        return
    fi
    ui_clear
    echo -e "${THEME_HEADER} Últimos 20 registros de bloqueos (Fail2Ban):${RST}"
    ui_bar
    tail -n 20 /var/log/fail2ban.log
    ui_bar
    ui_pause
}

main() {
    while true; do
        ui_clear
        ui_bar
        ui_title_small
        echo -e "${THEME_HEADER}       PROTECCION FAIL2BAN (ANTI-DDoS)${RST}"
        ui_bar
        
        local is_installed
        command -v fail2ban-client >/dev/null 2>&1 && is_installed=0 || is_installed=1
        
        if [[ $is_installed -eq 0 ]]; then
            echo -e " ${BCYAN}ℹ${RST} Fail2Ban está ${STATUS_ON} protegiendo tu servidor"
            echo -e "   bloqueando IPs sospechosas."
            ui_bar
            
            ui_menu_item 1 "Ver Registro de Logs / Bloqueos"
            ui_menu_item 2 "Desinstalar Fail2Ban" "${STATUS_OFF}"
            
            ui_bar
            ui_menu_back 0
            ui_bar
            
            local sel
            sel=$(ui_select 2)
            case "$sel" in
                1) view_logs ;;
                2) remove_fail2ban ;;
                0) return ;;
            esac
        else
            echo -e " ${BCYAN}ℹ${RST} Fail2Ban está ${STATUS_OFF}"
            echo -e "   Se recomienda activar para prevenir robo de accesos y spam."
            ui_bar
            
            ui_menu_item 1 "Instalar y Habilitar Fail2Ban"
            
            ui_bar
            ui_menu_back 0
            ui_bar
            
            local sel
            sel=$(ui_select 1)
            case "$sel" in
                1) install_fail2ban ;;
                0) return ;;
            esac
        fi
    done
}

main
