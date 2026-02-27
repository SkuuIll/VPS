#!/bin/bash
# ============================================================
# VPS-MX — Sistema de Colores y Temas Centralizado
# ============================================================
# Uso: source este archivo desde lib/config.sh
# Provee variables de color ANSI y funciones de colorización.
# ============================================================

# ── Prevenir doble-carga ──
[[ -n "$_VPS_COLORS_LOADED" ]] && return 0
_VPS_COLORS_LOADED=1

# ── Reset ──
export RST='\033[0m'

# ── Estilos ──
export BOLD='\033[1m'
export DIM='\033[2m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export INVERT='\033[7m'

# ── Colores de primer plano (Foreground) ──
export BLACK='\033[0;30m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'

# ── Colores Bold ──
export BRED='\033[1;31m'
export BGREEN='\033[1;32m'
export BYELLOW='\033[1;33m'
export BBLUE='\033[1;34m'
export BMAGENTA='\033[1;35m'
export BCYAN='\033[1;36m'
export BWHITE='\033[1;37m'

# ── Colores de fondo (Background) ──
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'
export BG_DARKGRAY='\033[100m'

# ── Colores extendidos (256-color si la terminal lo soporta) ──
export ORANGE='\033[38;5;208m'
export PINK='\033[38;5;213m'
export LIGHTGRAY='\033[38;5;250m'
export DARKGRAY='\033[38;5;240m'

# ── Indicadores de estado ──
export STATUS_ON="${BGREEN}[ON]${RST}"
export STATUS_OFF="${BRED}[OFF]${RST}"
export STATUS_OK="${BGREEN}[OK]${RST}"
export STATUS_FAIL="${BRED}[FAIL]${RST}"
export STATUS_WARN="${BYELLOW}[!]${RST}"

# ── Tema del panel (personalizable en /etc/VPS-MX/theme.conf) ──
# Colores por defecto para los elementos de la UI
export THEME_TITLE="${BCYAN}"
export THEME_HEADER="${BYELLOW}"
export THEME_MENU_NUM="${BGREEN}"
export THEME_MENU_ARROW="${BRED}"
export THEME_MENU_TEXT="${BWHITE}"
export THEME_BAR="${BYELLOW}"
export THEME_INPUT="${BWHITE}"
export THEME_SUCCESS="${BGREEN}"
export THEME_ERROR="${BRED}"
export THEME_WARNING="${BYELLOW}"
export THEME_INFO="${BCYAN}"
export THEME_ACCENT="${BMAGENTA}"

# ── Cargar tema personalizado si existe ──
_vps_load_theme() {
    local theme_file="${VPS_DIR:-/etc/VPS-MX}/theme.conf"
    if [[ -f "$theme_file" ]]; then
        # El archivo theme.conf puede contener líneas como:
        # THEME_TITLE='\033[1;91m'
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            key=$(echo "$key" | tr -d ' ')
            value=$(echo "$value" | tr -d "'" | tr -d '"' | tr -d ' ')
            case "$key" in
                THEME_*) export "$key"="$value" ;;
            esac
        done < "$theme_file"
    fi
}

# ── Función: colorize ──
# Uso: colorize "RED" "texto a colorear"
#      echo -e "$(colorize GREEN "OK")"
colorize() {
    local color_name="$1"
    local text="$2"
    local color_var

    case "$color_name" in
        RED)      color_var="$RED" ;;
        GREEN)    color_var="$GREEN" ;;
        YELLOW)   color_var="$YELLOW" ;;
        BLUE)     color_var="$BLUE" ;;
        CYAN)     color_var="$CYAN" ;;
        MAGENTA)  color_var="$MAGENTA" ;;
        WHITE)    color_var="$WHITE" ;;
        BRED)     color_var="$BRED" ;;
        BGREEN)   color_var="$BGREEN" ;;
        BYELLOW)  color_var="$BYELLOW" ;;
        BBLUE)    color_var="$BBLUE" ;;
        BCYAN)    color_var="$BCYAN" ;;
        BMAGENTA) color_var="$BMAGENTA" ;;
        BWHITE)   color_var="$BWHITE" ;;
        *)        color_var="$RST" ;;
    esac

    echo -e "${color_var}${text}${RST}"
}

# Cargar tema al source
_vps_load_theme
