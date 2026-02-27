#!/bin/bash
# ============================================================
# VPS -- Sistema de Expiracion de Cuentas
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

EXPIRE_DIR="${VPS_DIR}/expires"
mkdir -p "$EXPIRE_DIR"

# -- Crear usuario con expiracion --
create_user_with_expiry() {
    ui_bar
    local user pass days limit

    user=$(ui_input "Nombre del usuario" "^[a-zA-Z0-9_]+$")

    if id "$user" &>/dev/null; then
        ui_error "El usuario '$user' ya existe"
        return 1
    fi

    pass=$(ui_input "Contrasena" ".+")
    days=$(ui_input "Dias de duracion" "^[0-9]+$" "30")
    limit=$(ui_input "Limite de conexiones simultaneas" "^[0-9]+$" "1")

    # Calcular fecha de expiracion
    local expire_date
    expire_date=$(date -d "+${days} days" '+%Y-%m-%d')

    # Crear usuario con fecha de expiracion del sistema
    useradd -M -s /bin/false -e "$expire_date" "$user" 2>/dev/null
    echo "${user}:${pass}" | chpasswd 2>/dev/null

    # Guardar metadata
    cat > "${EXPIRE_DIR}/${user}.conf" << EOF
usuario=${user}
creado=$(date '+%Y-%m-%d %H:%M')
expira=${expire_date}
dias=${days}
limite=${limit}
estado=activo
EOF

    ui_success "Usuario creado con expiracion"
    echo -e "  ${BWHITE}Usuario:${RST}    ${BGREEN}${user}${RST}"
    echo -e "  ${BWHITE}Contrasena:${RST} ${BGREEN}${pass}${RST}"
    echo -e "  ${BWHITE}Expira:${RST}     ${BYELLOW}${expire_date}${RST} (${days} dias)"
    echo -e "  ${BWHITE}Limite:${RST}     ${BCYAN}${limit} conexiones${RST}"
    echo -e "  ${BWHITE}IP:${RST}         ${BCYAN}$(get_ip)${RST}"
    ui_bar

    log_info "Usuario creado: $user (expira: $expire_date, limite: $limit)"
}

# -- Verificar y bloquear cuentas expiradas --
check_expired() {
    local today
    today=$(date '+%Y-%m-%d')
    local expired=0 active=0

    echo -e "  ${BWHITE}USUARIO         EXPIRA          ESTADO        DIAS REST.${RST}"
    echo -e "  ${BYELLOW}$(printf '%0.s-' {1..60})${RST}"

    for conf in "${EXPIRE_DIR}"/*.conf; do
        [[ -f "$conf" ]] || continue
        source "$conf"

        local days_left
        days_left=$(( ( $(date -d "$expira" +%s) - $(date +%s) ) / 86400 ))

        local status_color status_text
        if (( days_left < 0 )); then
            status_color="$BRED"
            status_text="EXPIRADO"
            (( expired++ ))

            # Bloquear usuario si aun esta activo
            if [[ "$estado" == "activo" ]]; then
                usermod -L "$usuario" 2>/dev/null
                pkill -u "$usuario" 2>/dev/null
                sed -i "s/estado=activo/estado=bloqueado/" "$conf"
            fi
        elif (( days_left <= 3 )); then
            status_color="$BYELLOW"
            status_text="POR VENCER"
            (( active++ ))
        else
            status_color="$BGREEN"
            status_text="ACTIVO"
            (( active++ ))
        fi

        printf "  ${BGREEN}%-15s${RST} ${BCYAN}%-15s${RST} ${status_color}%-13s${RST} ${BWHITE}%s${RST}\n" \
            "$usuario" "$expira" "$status_text" "${days_left}d"
    done

    echo ""
    echo -e "  ${BGREEN}Activos: ${active}${RST}  |  ${BRED}Expirados: ${expired}${RST}"
}

# -- Renovar usuario --
renew_user() {
    ui_bar
    local user days

    user=$(ui_input "Usuario a renovar" "^[a-zA-Z0-9_]+$")

    if [[ ! -f "${EXPIRE_DIR}/${user}.conf" ]]; then
        ui_error "Usuario no encontrado en el sistema de expiracion"
        return 1
    fi

    days=$(ui_input "Dias adicionales" "^[0-9]+$" "30")

    source "${EXPIRE_DIR}/${user}.conf"
    local new_expire
    new_expire=$(date -d "+${days} days" '+%Y-%m-%d')

    # Actualizar expiracion del sistema
    chage -E "$new_expire" "$user" 2>/dev/null || usermod -e "$new_expire" "$user" 2>/dev/null

    # Desbloquear si estaba bloqueado
    usermod -U "$user" 2>/dev/null

    # Actualizar config
    sed -i "s/expira=.*/expira=${new_expire}/" "${EXPIRE_DIR}/${user}.conf"
    sed -i "s/estado=.*/estado=activo/" "${EXPIRE_DIR}/${user}.conf"

    ui_success "Usuario ${BGREEN}${user}${RST} renovado hasta ${BYELLOW}${new_expire}${RST}"
    ui_bar
    log_info "Usuario renovado: $user (nueva expiracion: $new_expire)"
}

# -- Eliminar usuario --
delete_user() {
    ui_bar
    local user
    user=$(ui_input "Usuario a eliminar" "^[a-zA-Z0-9_]+$")

    if ! id "$user" &>/dev/null && [[ ! -f "${EXPIRE_DIR}/${user}.conf" ]]; then
        ui_error "Usuario no encontrado"
        return 1
    fi

    if ui_confirm "Eliminar usuario ${user} permanentemente?"; then
        pkill -u "$user" 2>/dev/null
        userdel --force "$user" 2>/dev/null
        rm -f "${EXPIRE_DIR}/${user}.conf" 2>/dev/null

        ui_success "Usuario ${user} eliminado"
        log_info "Usuario eliminado: $user"
    fi
    ui_bar
}

# -- Auto-check (para cron) --
auto_check() {
    local today
    today=$(date '+%Y-%m-%d')

    for conf in "${EXPIRE_DIR}"/*.conf; do
        [[ -f "$conf" ]] || continue
        source "$conf"

        local days_left
        days_left=$(( ( $(date -d "$expira" +%s) - $(date +%s) ) / 86400 ))

        if (( days_left < 0 )) && [[ "$estado" == "activo" ]]; then
            usermod -L "$usuario" 2>/dev/null
            pkill -u "$usuario" 2>/dev/null
            sed -i "s/estado=activo/estado=bloqueado/" "$conf"
            log_info "Auto-bloqueado: $usuario (expirado $expira)"
        fi
    done
}

# Modo automatico si se pasa argumento
if [[ "${1:-}" == "--auto" ]]; then
    auto_check
    exit 0
fi

# -- Menu --
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}     SISTEMA DE EXPIRACION DE CUENTAS${RST}"
    ui_bar

    ui_menu_item 1 "Crear usuario con expiracion"
    ui_menu_item 2 "Ver estado de cuentas"
    ui_menu_item 3 "Renovar usuario"
    ui_menu_item 4 "Eliminar usuario"
    ui_menu_item 5 "Verificar expirados ahora"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 5)

    case "$sel" in
        1) create_user_with_expiry ;;
        2) ui_bar; check_expired; ui_bar ;;
        3) renew_user ;;
        4) delete_user ;;
        5) ui_bar; auto_check; check_expired; ui_bar ;;
        0) return ;;
    esac
}

main
