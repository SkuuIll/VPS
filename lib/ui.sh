#!/bin/bash
# ============================================================
# VPS — Funciones de Interfaz de Usuario
# ============================================================
# Uso: source este archivo desde lib/config.sh
# Reemplaza todas las funciones msg, barras, selectores y
# progress bars que estaban duplicadas en cada script.
# ============================================================

[[ -n "$_VPS_UI_LOADED" ]] && return 0
_VPS_UI_LOADED=1

# ── Ancho de la terminal ──
_ui_width() {
    local cols
    cols=$(tput cols 2>/dev/null) || cols=60
    echo "$cols"
}

# ── Barra separadora ──
ui_bar() {
    local width=$(_ui_width)
    local char="${1:--}"
    local color="${2:-$THEME_BAR}"
    printf "${color}"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf "${RST}\n"
}

# ── Barra doble ──
ui_bar2() {
    ui_bar "=" "$THEME_BAR"
}

# ── Título del panel VPS ──
ui_title() {
    echo -e "${THEME_TITLE}"
    echo -e "  ██╗   ██╗██████╗ ███████╗    ███╗   ███╗██╗  ██╗"
    echo -e "  ██║   ██║██╔══██╗██╔════╝    ████╗ ████║╚██╗██╔╝"
    echo -e "  ██║   ██║██████╔╝███████╗    ██╔████╔██║ ╚███╔╝ "
    echo -e "  ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║ ██╔██╗ "
    echo -e "   ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║██╔╝ ██╗"
    echo -e "    ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝"
    echo -e "${RST}"
}

# ── Título compacto (una línea) ──
ui_title_small() {
    echo -e "${THEME_TITLE}  ━━━ VPS•MX Panel ━━━${RST}"
}

# ── Header de sección ──
ui_header() {
    local text="$1"
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}  ${text}${RST}"
    ui_bar
}

# ── Mensajes con niveles ──
ui_success() { echo -e " ${BGREEN}✔${RST} ${THEME_SUCCESS}$*${RST}"; }
ui_error()   { echo -e " ${BRED}✘${RST} ${THEME_ERROR}$*${RST}"; }
ui_warn()    { echo -e " ${BYELLOW}⚠${RST} ${THEME_WARNING}$*${RST}"; }
ui_info()    { echo -e " ${BCYAN}ℹ${RST} ${THEME_INFO}$*${RST}"; }
ui_step()    { echo -e " ${BBLUE}▸${RST} ${BWHITE}$*${RST}"; }

# ── Mensaje verde (compatibilidad) ──
ui_msg_green()  { echo -e " ${BGREEN}$*${RST}"; }
ui_msg_red()    { echo -e " ${BRED}$*${RST}"; }
ui_msg_yellow() { echo -e " ${BYELLOW}$*${RST}"; }
ui_msg_blue()   { echo -e " ${BBLUE}$*${RST}"; }
ui_msg_cyan()   { echo -e " ${BCYAN}$*${RST}"; }
ui_msg_white()  { echo -e " ${BWHITE}$*${RST}"; }

# ── Progress bar con spinner ──
# Uso: run_with_spinner "Instalando paquete..." "apt-get install -y foo"
run_with_spinner() {
    local msg="$1"
    shift
    local cmd="$*"
    local spinchars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local pid

    # Ejecutar comando en background
    eval "$cmd" > /dev/null 2>&1 &
    pid=$!

    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        local idx=$(( i % ${#spinchars} ))
        printf "\r ${BCYAN}${spinchars:$idx:1}${RST} ${BWHITE}%s${RST}" "$msg"
        sleep 0.1
        (( i++ ))
    done

    wait "$pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        printf "\r ${BGREEN}✔${RST} ${BWHITE}%s${RST}\n" "$msg"
    else
        printf "\r ${BRED}✘${RST} ${BWHITE}%s${RST}\n" "$msg"
    fi
    return $exit_code
}

# ── Progress bar clásica (estilo VPS original mejorado) ──
# Uso: run_with_bar "Configurando..." "command"
run_with_bar() {
    local msg="$1"
    shift
    local cmd="$*"

    eval "$cmd" > /dev/null 2>&1 &
    local pid=$!

    echo -ne " ${BYELLOW}[${RST}"
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "${BRED}█${RST}"
        sleep 0.3
    done

    wait "$pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${BYELLOW}]${RST} ${BGREEN}100%${RST} ${msg}"
    else
        echo -e "${BYELLOW}]${RST} ${BRED}FAIL${RST} ${msg}"
    fi
    return $exit_code
}

# ── Imprimir un ítem de menú ──
# Uso: ui_menu_item 1 "OPENSSH" "[ON]"
ui_menu_item() {
    local num="$1"
    local text="$2"
    local status="${3:-}"

    printf " ${THEME_MENU_NUM}[%2d]${RST} ${THEME_MENU_ARROW}▸${RST} ${THEME_MENU_TEXT}%-40s${RST}" "$num" "$text"
    if [[ -n "$status" ]]; then
        echo -e " $status"
    else
        echo ""
    fi
}

# ── Imprimir botón de volver ──
ui_menu_back() {
    local num="${1:-0}"
    echo -e " ${THEME_MENU_NUM}[${num}]${RST} ${THEME_MENU_ARROW}▸${RST} ${BG_RED}${BWHITE} VOLVER ${RST}"
}

# ── Separador de sección en menú ──
ui_menu_section() {
    local title="$1"
    echo -e "${BYELLOW}  ──── ${title} ────${RST}"
}

# ── Seleccionar una opción numérica ──
# Uso: selection=$(ui_select $max_num)
ui_select() {
    local max="$1"
    local selection=""
    local valid=false

    while [[ "$valid" != "true" ]]; do
        echo -ne "${THEME_INPUT} ► Seleccione una opción: ${RST}"
        read -r selection
        tput cuu1 && tput dl1

        # Validar que es un número entre 0 y max
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 0 && selection <= max )); then
            valid=true
        fi
    done
    echo "$selection"
}

# ── Confirmación S/N ──
# Uso: if ui_confirm "¿Desea continuar?"; then ...
ui_confirm() {
    local prompt="${1:-¿Está seguro?}"
    local default="${2:-n}"
    local answer

    if [[ "$default" == "s" || "$default" == "y" ]]; then
        echo -ne "${THEME_INPUT} ${prompt} [S/n]: ${RST}"
    else
        echo -ne "${THEME_INPUT} ${prompt} [s/N]: ${RST}"
    fi

    read -r answer
    answer="${answer:-$default}"

    case "$answer" in
        s|S|y|Y) return 0 ;;
        *)       return 1 ;;
    esac
}

# ── Pedir input con validación ──
# Uso: value=$(ui_input "Ingrese el puerto" "^[0-9]+$")
ui_input() {
    local prompt="$1"
    local pattern="${2:-.*}"
    local default="$3"
    local value=""

    while true; do
        if [[ -n "$default" ]]; then
            echo -ne "${THEME_INPUT} ${prompt} [${default}]: ${RST}"
        else
            echo -ne "${THEME_INPUT} ${prompt}: ${RST}"
        fi
        read -r value
        value="${value:-$default}"

        if [[ "$value" =~ $pattern ]]; then
            break
        fi
        tput cuu1 && tput dl1
    done
    echo "$value"
}

# ── Limpiar pantalla ──
ui_clear() {
    clear
}

# ── Pausa "Enter para continuar" ──
ui_pause() {
    local msg="${1:-Presione Enter para continuar...}"
    echo -ne "${THEME_INPUT} ${msg}${RST}"
    read -r _
}

# ── Mostrar estado de servicio ON/OFF ──
ui_service_status() {
    local name="$1"
    local running="$2"  # 0=running, 1=stopped

    if [[ "$running" -eq 0 ]]; then
        echo -e "${STATUS_ON}"
    else
        echo -e "${STATUS_OFF}"
    fi
}
