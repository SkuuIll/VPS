#!/bin/bash
# ============================================================
# VPS -- Backup y Restore Automatico
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

BACKUP_DIR="/root/vps-backups"

# -- Crear backup completo --
create_backup() {
    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/vps-backup-${timestamp}.tar.gz"

    ui_step "Creando backup completo..."
    ui_bar

    local tmp_dir="/tmp/vps-backup-${timestamp}"
    mkdir -p "$tmp_dir"

    # Panel completo
    cp -r "$VPS_DIR" "${tmp_dir}/VPS" 2>/dev/null

    # Configs de servicios
    mkdir -p "${tmp_dir}/configs"
    [[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config "${tmp_dir}/configs/"
    [[ -f /etc/default/dropbear ]] && cp /etc/default/dropbear "${tmp_dir}/configs/"
    [[ -f /etc/stunnel/stunnel.conf ]] && cp /etc/stunnel/stunnel.conf "${tmp_dir}/configs/" 2>/dev/null
    [[ -f /etc/stunnel/stunnel.pem ]] && cp /etc/stunnel/stunnel.pem "${tmp_dir}/configs/" 2>/dev/null

    # Squid
    [[ -f /etc/squid/squid.conf ]] && cp /etc/squid/squid.conf "${tmp_dir}/configs/squid.conf"
    [[ -f /etc/squid3/squid.conf ]] && cp /etc/squid3/squid.conf "${tmp_dir}/configs/squid3.conf"

    # OpenVPN
    [[ -d /etc/openvpn ]] && cp -r /etc/openvpn "${tmp_dir}/configs/openvpn" 2>/dev/null

    # iptables
    iptables-save > "${tmp_dir}/configs/iptables.rules" 2>/dev/null

    # sysctl custom
    [[ -f /etc/sysctl.d/99-vps.conf ]] && cp /etc/sysctl.d/99-vps.conf "${tmp_dir}/configs/"

    # Lista de usuarios SSH
    grep '/bin/false\|/home' /etc/passwd > "${tmp_dir}/configs/users.list" 2>/dev/null

    # Crear tarball
    tar -czf "$backup_file" -C /tmp "vps-backup-${timestamp}" 2>/dev/null
    rm -rf "$tmp_dir"

    local size=$(du -h "$backup_file" | awk '{print $1}')

    ui_success "Backup creado exitosamente"
    echo -e "  ${BWHITE}Archivo:${RST}  ${BCYAN}${backup_file}${RST}"
    echo -e "  ${BWHITE}Tamano:${RST}   ${BGREEN}${size}${RST}"
    echo -e "  ${BWHITE}Fecha:${RST}    ${BGREEN}$(date)${RST}"
    ui_bar
    log_info "Backup creado: $backup_file ($size)"
}

# -- Listar backups disponibles --
list_backups() {
    ui_step "Backups disponibles:"
    ui_bar

    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]]; then
        ui_warn "No hay backups disponibles"
        return 1
    fi

    local i=0
    local files=()
    while IFS= read -r f; do
        (( i++ ))
        files+=("$f")
        local name=$(basename "$f")
        local size=$(du -h "$f" | awk '{print $1}')
        local date=$(stat -c '%y' "$f" | cut -d'.' -f1)
        printf "  ${BGREEN}[%d]${RST} ${BWHITE}%-40s${RST} ${BCYAN}%s${RST}  ${BYELLOW}%s${RST}\n" "$i" "$name" "$size" "$date"
    done <<< "$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)"

    echo ""
    echo "${i}" > /tmp/vps-backup-count.tmp
    printf '%s\n' "${files[@]}" > /tmp/vps-backup-list.tmp
    return 0
}

# -- Restaurar backup --
restore_backup() {
    if ! list_backups; then
        return 1
    fi

    ui_bar
    local count=$(cat /tmp/vps-backup-count.tmp)
    local sel
    sel=$(ui_input "Seleccione backup a restaurar (1-${count})" "^[0-9]+$")

    local file=$(sed -n "${sel}p" /tmp/vps-backup-list.tmp)
    rm -f /tmp/vps-backup-count.tmp /tmp/vps-backup-list.tmp

    if [[ ! -f "$file" ]]; then
        ui_error "Backup no encontrado"
        return 1
    fi

    ui_warn "Esto sobreescribira la configuracion actual"
    if ! ui_confirm "Continuar con la restauracion?"; then
        return 0
    fi

    ui_step "Restaurando backup..."
    local tmp_dir="/tmp/vps-restore-$$"
    mkdir -p "$tmp_dir"
    tar -xzf "$file" -C "$tmp_dir" 2>/dev/null

    local extracted=$(ls "$tmp_dir")

    # Restaurar panel
    if [[ -d "${tmp_dir}/${extracted}/VPS" ]]; then
        cp -rf "${tmp_dir}/${extracted}/VPS/"* "$VPS_DIR/" 2>/dev/null
        ui_success "Panel restaurado"
    fi

    # Restaurar configs
    local cfg="${tmp_dir}/${extracted}/configs"
    if [[ -d "$cfg" ]]; then
        [[ -f "${cfg}/sshd_config" ]] && cp "${cfg}/sshd_config" /etc/ssh/ && service_ctl restart ssh
        [[ -f "${cfg}/dropbear" ]] && cp "${cfg}/dropbear" /etc/default/ && service_ctl restart dropbear
        [[ -f "${cfg}/stunnel.conf" ]] && cp "${cfg}/stunnel.conf" /etc/stunnel/ && service_ctl restart stunnel4
        [[ -f "${cfg}/squid.conf" ]] && cp "${cfg}/squid.conf" /etc/squid/ && service_ctl restart squid
        [[ -f "${cfg}/iptables.rules" ]] && iptables-restore < "${cfg}/iptables.rules" 2>/dev/null
        ui_success "Configuraciones restauradas"
    fi

    rm -rf "$tmp_dir"
    ui_success "Restauracion completada"
    ui_bar
    log_info "Backup restaurado: $file"
}

# -- Eliminar backups viejos --
clean_backups() {
    list_backups || return
    ui_bar

    local days
    days=$(ui_input "Eliminar backups mayores a X dias" "^[0-9]+$" "30")

    local deleted=0
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +"$days" -exec rm -f {} \; -exec echo "deleted" \; | while read -r _; do (( deleted++ )); done

    ui_success "Backups antiguos eliminados (>${days} dias)"
    ui_bar
}

# -- Menu --
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}        BACKUP Y RESTORE${RST}"
    ui_bar

    ui_menu_item 1 "Crear backup completo"
    ui_menu_item 2 "Restaurar backup"
    ui_menu_item 3 "Listar backups"
    ui_menu_item 4 "Limpiar backups antiguos"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 4)

    case "$sel" in
        1) create_backup ;;
        2) restore_backup ;;
        3) list_backups; ui_bar ;;
        4) clean_backups ;;
        0) return ;;
    esac
}

main
