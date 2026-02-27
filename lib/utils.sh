#!/bin/bash
# ============================================================
# VPS — Utilidades Comunes
# ============================================================
# Uso: source este archivo desde lib/config.sh
# Funciones de validación, logging, backup, y helpers generales.
# ============================================================

[[ -n "$_VPS_UTILS_LOADED" ]] && return 0
_VPS_UTILS_LOADED=1

# ── Logging ──
_LOG_FILE="${VPS_DIR:-/etc/VPS}/vps.log"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$_LOG_FILE" 2>/dev/null
}

log_info()  { log "INFO"  "$@"; }
log_warn()  { log "WARN"  "$@"; }
log_error() { log "ERROR" "$@"; }

# ── Verificar root ──
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${BRED}Error: Este script debe ejecutarse como root${RST}" >&2
        exit 1
    fi
}

# ── Verificar dependencias ──
# Uso: check_deps curl wget jq
check_deps() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${BYELLOW}⚠ Dependencias faltantes: ${missing[*]}${RST}"
        echo -e "${BWHITE}  Instalando...${RST}"
        apt-get update -qq > /dev/null 2>&1
        for pkg in "${missing[@]}"; do
            apt-get install -y -qq "$pkg" > /dev/null 2>&1
        done
        return $?
    fi
    return 0
}

# ── Validar que un string es un puerto válido ──
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
        return 0
    fi
    return 1
}

# ── Validar que un puerto está libre ──
is_port_available() {
    local port="$1"
    ! is_port_used "$port"
}

# ── Sanitizar entrada del usuario ──
sanitize_input() {
    local input="$1"
    # Eliminar caracteres peligrosos
    echo "$input" | tr -d ';&|`$(){}[]<>!\\' | xargs
}

# ── Crear backup de un archivo antes de modificarlo ──
backup_file() {
    local file="$1"
    local backup_dir="${VPS_DIR}/backups"

    [[ ! -d "$backup_dir" ]] && mkdir -p "$backup_dir"

    if [[ -f "$file" ]]; then
        local basename
        basename=$(basename "$file")
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        cp "$file" "${backup_dir}/${basename}.${timestamp}.bak"
        log_info "Backup creado: ${backup_dir}/${basename}.${timestamp}.bak"
        return 0
    fi
    return 1
}

# ── Restaurar archivo desde backup ──
restore_file() {
    local file="$1"
    local backup_dir="${VPS_DIR}/backups"
    local basename
    basename=$(basename "$file")

    # Buscar el backup más reciente
    local latest
    latest=$(ls -t "${backup_dir}/${basename}".*.bak 2>/dev/null | head -1)

    if [[ -n "$latest" && -f "$latest" ]]; then
        cp "$latest" "$file"
        log_info "Archivo restaurado desde: $latest"
        return 0
    fi

    log_error "No se encontró backup para: $file"
    return 1
}

# ── Descargar archivo con reintentos ──
download_file() {
    local url="$1"
    local dest="$2"
    local max_retries="${3:-3}"
    local retry=0

    while (( retry < max_retries )); do
        if curl -sSL --max-time 30 -o "$dest" "$url" 2>/dev/null; then
            return 0
        elif wget -q --timeout=30 -O "$dest" "$url" 2>/dev/null; then
            return 0
        fi
        (( retry++ ))
        sleep 2
    done

    log_error "No se pudo descargar: $url (después de $max_retries intentos)"
    return 1
}

# ── Generar contraseña aleatoria ──
generate_password() {
    local length="${1:-12}"
    tr -dc 'A-Za-z0-9!@#$%' < /dev/urandom | head -c "$length"
}

# ── Convertir bytes a formato legible ──
human_size() {
    local bytes="$1"
    if (( bytes >= 1073741824 )); then
        echo "$(( bytes / 1073741824 ))GB"
    elif (( bytes >= 1048576 )); then
        echo "$(( bytes / 1048576 ))MB"
    elif (( bytes >= 1024 )); then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

# ── Verificar conectividad a internet ──
check_internet() {
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        return 0
    elif curl -s --max-time 5 https://www.google.com &>/dev/null; then
        return 0
    fi
    return 1
}

# ── Trap handler para limpieza ──
cleanup() {
    # Limpiar archivos temporales
    rm -f /tmp/vps-*.tmp 2>/dev/null
    tput cnorm 2>/dev/null  # Restaurar cursor
}
trap cleanup EXIT

# ── Obtener la versión del script ──
get_version() {
    echo "${VPS_VERSION:-2.0.0}"
}
