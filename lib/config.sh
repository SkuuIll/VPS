#!/bin/bash
# ============================================================
# VPS-MX — Configuración Central
# ============================================================
# Este es el ÚNICO archivo que cada script necesita cargar:
#   source /etc/VPS-MX/lib/config.sh
# Carga automáticamente todas las demás librerías y define
# las variables globales del proyecto.
# ============================================================

[[ -n "$_VPS_CONFIG_LOADED" ]] && return 0
_VPS_CONFIG_LOADED=1

# ── Versión ──
export VPS_VERSION="2.0.0"
export VPS_CODENAME="Modernizado"

# ── Rutas principales ──
# Soporta tanto la ruta de desarrollo como la de producción
if [[ -d "/root/VPS-MX-DEV/lib" && -f "/root/VPS-MX-DEV/lib/config.sh" ]]; then
    export VPS_BASE="/root/VPS-MX-DEV"
else
    export VPS_BASE="/etc/VPS-MX"
fi

export VPS_DIR="/etc/VPS-MX"
export VPS_LIB="${VPS_BASE}/lib"
export VPS_CTRL="${VPS_DIR}/controlador"
export VPS_TOOLS="${VPS_DIR}/herramientas"
export VPS_PROTO="${VPS_DIR}/protocolos"
export VPS_SERVICES="${VPS_BASE}/services"
export VPS_BACKUPS="${VPS_DIR}/backups"
export VPS_LOGS="${VPS_DIR}/logs"

# ── Archivos de datos ──
export VPS_IP_CACHE="${VPS_DIR}/MEUIPvps"
export VPS_LOG_FILE="${VPS_DIR}/vps-mx.log"
export VPS_PANEL_NAME="VPS-MX"

# ── Archivos del controlador ──
export VPS_USERCODES="${VPS_CTRL}/usercodes"
export VPS_SSH_LOG="${VPS_CTRL}/SSH20.log"
export VPS_TIMELIM_LOG="${VPS_CTRL}/tiemlim.log"
export VPS_NAME_LOG="${VPS_CTRL}/nombre.log"

# ── Crear directorios si no existen ──
_vps_ensure_dirs() {
    local dirs=(
        "$VPS_DIR"
        "$VPS_CTRL"
        "$VPS_TOOLS"
        "$VPS_PROTO"
        "$VPS_BACKUPS"
        "$VPS_LOGS"
    )
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && mkdir -p "$dir"
    done
}
_vps_ensure_dirs

# ── Cargar librerías en orden ──
source "${VPS_LIB}/colors.sh"
source "${VPS_LIB}/ui.sh"
source "${VPS_LIB}/system.sh"
source "${VPS_LIB}/utils.sh"

# ── Idioma ──
export VPS_LANG="es"

# ── Información del sistema (se carga una vez) ──
export VPS_OS
VPS_OS=$(get_os)

# ── Aliases de compatibilidad ──
# Estas funciones mantienen compatibilidad con los scripts
# que aún no han sido migrados y usan los nombres viejos.
# Se pueden eliminar cuando la migración esté completa.

# msg function (backward-compatible wrapper)
msg() {
    case "$1" in
        -bar)   ui_bar ;;
        -bar2)  ui_bar2 ;;
        -bar3)  ui_bar ;;
        -tit)   ui_title_small ;;
        -verd)  shift; echo -ne " ${BGREEN}$*${RST}" ;;
        -verm)  shift; echo -e " ${BRED}$*${RST}" ;;
        -verm2) shift; echo -ne "${BRED}$*${RST}" ;;
        -ama)   shift; echo -e " ${BYELLOW}$*${RST}" ;;
        -azu)   shift; echo -e "${BCYAN}$*${RST}" ;;
        -bra)   shift; echo -e " ${BWHITE}$*${RST}" ;;
        -ne)    shift; echo -ne " ${BWHITE}$*${RST}" ;;
        *)      echo -e "$*" ;;
    esac
}

# Funciones de selección (backward-compatible)
selection_fun() {
    ui_select "$1"
}

# Fun trans (simplificado - solo echo, sin google translate)
fun_trans() {
    echo "$*"
}

# meu_ip (backward-compatible)
meu_ip() {
    get_ip
}

fun_ip() {
    export IP
    IP=$(get_ip)
}

# os_system (backward-compatible)
os_system() {
    get_os | awk '{print $1, $2}'
}

# pid_inst (backward-compatible)
pid_inst() {
    service_status "$1"
}

# fun_bar (backward-compatible)
fun_bar() {
    run_with_spinner "$1" "$1"
}

# SPR dummy (el original no hacía nada útil)
SPR() {
    :
}

# Exportar funciones para subshells
export -f msg
export -f selection_fun
export -f fun_trans
export -f menu_func 2>/dev/null
export -f meu_ip
export -f fun_ip
export -f os_system
export -f pid_inst
export -f fun_bar
export -f SPR
