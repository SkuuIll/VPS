#!/bin/bash
# ============================================================
# VPS-MX — Gestión Interna del VPS
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

# ── Actualizar paquetes ──
update_packages() {
    ui_bar
    run_with_spinner "apt-get update" "apt-get update -y"
    run_with_spinner "apt-get upgrade" "apt-get upgrade -y"
    ui_bar
    ui_success "Actualización completa"
    ui_bar
}

# ── Reiniciar servicios ──
restart_services() {
    ui_bar
    local services=(stunnel4 squid squid3 apache2 openvpn dropbear ssh fail2ban)
    for svc in "${services[@]}"; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1 || [[ -f "/etc/init.d/${svc}" ]]; then
            if service_ctl restart "$svc"; then
                echo -e "  ${BGREEN}✔${RST} ${svc}"
            else
                echo -e "  ${BRED}✘${RST} ${svc} (no instalado o fallo)"
            fi
        fi
    done
    ui_bar
    ui_success "Servicios reiniciados"
    ui_bar
}

# ── Reiniciar VPS ──
reboot_vps() {
    if ui_confirm "¿Reiniciar el VPS ahora?"; then
        ui_step "Reiniciando en 3 segundos..."
        sleep 3
        sudo reboot
    fi
}

# ── Cambiar hostname ──
change_hostname() {
    local name
    name=$(ui_input "Nuevo nombre del host" "^[a-zA-Z0-9._-]+$")
    hostnamectl set-hostname "$name"
    if [[ "$(hostname)" == "$name" ]]; then
        ui_success "Hostname cambiado a: ${BGREEN}${name}${RST}"
    else
        ui_error "No se pudo cambiar el hostname"
    fi
    ui_bar
}

# ── Cambiar contraseña root ──
change_password() {
    ui_info "Cambiar la contraseña del usuario root"
    ui_bar
    if ui_confirm "¿Desea continuar?"; then
        local pass
        echo -ne " ${BWHITE}Nueva contraseña: ${RST}"
        read -rs pass
        echo ""
        echo "$pass" | chpasswd <<< "root:$pass" 2>/dev/null || (echo "$pass"; echo "$pass") | passwd root 2>/dev/null
        ui_bar
        ui_success "Contraseña cambiada"
    fi
    ui_bar
}

# ── Habilitar root en Google Cloud / Amazon ──
enable_root_login() {
    ui_info "Habilitar login root para Google Cloud / Amazon"
    ui_bar
    if ui_confirm "¿Desea continuar?"; then
        backup_file /etc/ssh/sshd_config
        sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        service_ctl restart ssh
        ui_bar
        local pass
        echo -ne " ${BWHITE}Contraseña root: ${RST}"
        read -rs pass
        echo ""
        echo "root:$pass" | chpasswd 2>/dev/null || (echo "$pass"; echo "$pass") | passwd root 2>/dev/null
        ui_bar
        ui_success "Root habilitado. Contraseña: ${BGREEN}${pass}${RST}"
    fi
    ui_bar
}

# ── Cambiar zona horaria ──
change_timezone() {
    ui_bar
    echo -e "  ${BGREEN}[1]${RST} México (America/Mexico_City)"
    echo -e "  ${BGREEN}[2]${RST} Argentina (America/Buenos_Aires)"
    echo -e "  ${BGREEN}[3]${RST} Colombia (America/Bogota)"
    echo -e "  ${BGREEN}[4]${RST} Venezuela (America/Caracas)"
    echo -e "  ${BGREEN}[5]${RST} Chile (America/Santiago)"
    echo -e "  ${BGREEN}[6]${RST} Perú (America/Lima)"
    echo -e "  ${BGREEN}[7]${RST} USA Eastern (America/New_York)"
    echo -e "  ${BGREEN}[8]${RST} Personalizado"
    ui_bar

    local sel
    sel=$(ui_select 8)
    local tz=""

    case "$sel" in
        1) tz="America/Mexico_City" ;;
        2) tz="America/Argentina/Buenos_Aires" ;;
        3) tz="America/Bogota" ;;
        4) tz="America/Caracas" ;;
        5) tz="America/Santiago" ;;
        6) tz="America/Lima" ;;
        7) tz="America/New_York" ;;
        8)
            echo -ne " ${BWHITE}Zona horaria (ej: America/Lima): ${RST}"
            read -r tz
            ;;
        0) return ;;
    esac

    if [[ -n "$tz" ]]; then
        timedatectl set-timezone "$tz" 2>/dev/null || {
            rm -f /etc/localtime
            ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime
        }
        ui_success "Zona horaria: ${BGREEN}${tz}${RST}"
        echo -e "  ${BWHITE}Hora actual: $(date)${RST}"
    fi
    ui_bar
}

# ── Menú principal ──
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}           AJUSTES INTERNOS DEL VPS${RST}"
    ui_bar

    ui_menu_item 1 "Actualizar VPS (apt upgrade)"
    ui_menu_item 2 "Reiniciar Servicios"
    ui_menu_item 3 "Reiniciar VPS"
    ui_menu_item 4 "Cambiar Hostname"
    ui_menu_item 5 "Cambiar Contraseña Root"
    ui_menu_item 6 "Cambiar Zona Horaria"
    ui_menu_item 7 "Habilitar Root (GCloud/Amazon)"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 7)

    case "$sel" in
        1) update_packages ;;
        2) restart_services ;;
        3) reboot_vps ;;
        4) change_hostname ;;
        5) change_password ;;
        6) change_timezone ;;
        7) enable_root_login ;;
        0) return ;;
    esac
}

main