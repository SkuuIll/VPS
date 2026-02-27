#!/bin/bash
# ============================================================
# VPS-MX — Dropbear SSH Installer
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

install_dropbear() {
    ui_msg_green "INSTALADOR DROPBEAR"
    ui_bar

    local port
    port=$(ui_input "Puerto para Dropbear" "^[0-9]+$" "443")

    if is_port_used "$port"; then
        ui_error "Puerto ${port} ya está en uso"
        return 1
    fi

    run_with_spinner "Instalando Dropbear..." "apt-get install -y dropbear"

    backup_file /etc/default/dropbear

    # Configurar
    sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
    sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=${port}/" /etc/default/dropbear

    # Si no existe DROPBEAR_PORT, agregar
    if ! grep -q "DROPBEAR_PORT" /etc/default/dropbear; then
        echo "DROPBEAR_PORT=${port}" >> /etc/default/dropbear
    fi

    service_ctl restart dropbear

    if is_running dropbear; then
        ui_success "Dropbear instalado en puerto ${BGREEN}${port}${RST}"
    else
        ui_error "Error al iniciar Dropbear"
    fi
    ui_bar
}

uninstall_dropbear() {
    if ui_confirm "¿Desinstalar Dropbear?"; then
        service_ctl stop dropbear
        run_with_spinner "Desinstalando..." "apt-get purge -y dropbear"
        ui_success "Dropbear desinstalado"
    fi
    ui_bar
}

add_port() {
    ui_msg_yellow "AGREGAR PUERTO DROPBEAR"
    ui_bar

    local port
    port=$(ui_input "Nuevo puerto adicional" "^[0-9]+$")

    if is_port_used "$port"; then
        ui_error "Puerto ${port} ya está en uso"
        return 1
    fi

    backup_file /etc/default/dropbear

    local current
    current=$(grep "DROPBEAR_EXTRA_ARGS" /etc/default/dropbear | grep -oP '\-p \d+' | tr '\n' ' ')
    current+="-p ${port} "

    sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"${current}\"/" /etc/default/dropbear

    if ! grep -q "DROPBEAR_EXTRA_ARGS" /etc/default/dropbear; then
        echo "DROPBEAR_EXTRA_ARGS=\"-p ${port}\"" >> /etc/default/dropbear
    fi

    service_ctl restart dropbear
    ui_success "Puerto ${BGREEN}${port}${RST} agregado a Dropbear"
    ui_bar
}

main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}         DROPBEAR SSH${RST}"
    ui_bar

    local st=$(service_status dropbear)

    ui_menu_item 1 "Instalar Dropbear"   "$st"
    ui_menu_item 2 "Agregar Puerto"
    ui_menu_item 3 "Desinstalar Dropbear"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 3)

    case "$sel" in
        1)
            if is_running dropbear; then
                uninstall_dropbear
            else
                install_dropbear
            fi
            ;;
        2) add_port ;;
        3) uninstall_dropbear ;;
        0) return ;;
    esac
}

main