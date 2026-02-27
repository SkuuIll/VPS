#!/bin/bash
# ============================================================
# VPS-MX — Crear Usuario Temporal por Minutos
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}    CREAR USUARIO TEMPORAL (por minutos)${RST}"
    ui_bar
    ui_info "Los usuarios creados aquí se eliminan automáticamente"
    ui_info "al cumplirse el tiempo designado."
    ui_bar

    # ── Nombre ──
    local name
    name=$(ui_input "Nombre del usuario" "^[a-zA-Z0-9_]+$")

    # Verificar que no existe
    if id "$name" &>/dev/null; then
        ui_error "El usuario '${name}' ya existe"
        return 1
    fi

    # ── Contraseña ──
    local pass
    pass=$(ui_input "Contraseña" ".+")

    # ── Tiempo ──
    local minutes
    minutes=$(ui_input "Duración en minutos" "^[0-9]+$" "30")

    # ── Crear usuario ──
    useradd -M -s /bin/false "$name" 2>/dev/null
    echo "${name}:${pass}" | chpasswd 2>/dev/null

    # ── Crear cleanup script ──
    local cleanup_script="/tmp/vps-mx-tmpuser-${name}.sh"
    cat > "$cleanup_script" << CLEANUP
#!/bin/bash
sleep $(( minutes * 60 ))
pkill -u "${name}" 2>/dev/null
userdel --force "${name}" 2>/dev/null
rm -f "${cleanup_script}"
CLEANUP
    chmod 700 "$cleanup_script"
    nohup bash "$cleanup_script" &>/dev/null &

    # ── Registrar ──
    mkdir -p "${VPS_DIR}/demo-ssh"
    echo "pass: ${pass}" > "${VPS_DIR}/demo-ssh/${name}"
    echo "duracion: ${minutes} minutos" >> "${VPS_DIR}/demo-ssh/${name}"
    echo "creado: $(date)" >> "${VPS_DIR}/demo-ssh/${name}"

    log_info "Usuario temporal creado: ${name} (${minutes}min)"

    # ── Mostrar resumen ──
    ui_bar
    echo -e "${BYELLOW}  USUARIO TEMPORAL CREADO${RST}"
    ui_bar
    echo -e "  ${BWHITE}IP:${RST}          ${BCYAN}$(get_ip)${RST}"
    echo -e "  ${BWHITE}Usuario:${RST}     ${BGREEN}${name}${RST}"
    echo -e "  ${BWHITE}Contraseña:${RST}  ${BGREEN}${pass}${RST}"
    echo -e "  ${BWHITE}Duración:${RST}    ${BYELLOW}${minutes} minutos${RST}"
    ui_bar
}

main
