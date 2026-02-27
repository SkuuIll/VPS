#!/bin/bash
# ============================================================
# VPS — Funciones de Sistema
# ============================================================
# Uso: source este archivo desde lib/config.sh
# Reemplaza funciones duplicadas: meu_ip, fun_ip, mportas,
# pid_inst, os_system, systen_info, etc.
# ============================================================

[[ -n "$_VPS_SYSTEM_LOADED" ]] && return 0
_VPS_SYSTEM_LOADED=1

# ── Obtener IP pública del servidor ──
# Cachea el resultado en $VPS_DIR/MEUIPvps
get_ip() {
    local cache_file="${VPS_DIR}/MEUIPvps"

    # Si existe cache y tiene menos de 24h, usar cache
    if [[ -f "$cache_file" ]]; then
        local cache_age
        cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
        if (( cache_age < 86400 )); then
            cat "$cache_file"
            return 0
        fi
    fi

    # Intentar obtener IP de múltiples fuentes
    local ip=""
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null) \
        || ip=$(curl -s --max-time 5 ipv4.icanhazip.com 2>/dev/null) \
        || ip=$(curl -s --max-time 5 api.ipify.org 2>/dev/null) \
        || ip=$(wget -qO- --timeout=5 ifconfig.me 2>/dev/null)

    if [[ -n "$ip" ]]; then
        echo "$ip" > "$cache_file"
        echo "$ip"
    else
        # Fallback a IP local
        ip=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        echo "${ip:-desconocida}"
    fi
}

# ── Obtener IP local (privada) ──
get_local_ip() {
    ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1
}

# ── Detectar sistema operativo ──
get_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${PRETTY_NAME:-${NAME} ${VERSION_ID}}"
    elif [[ -f /etc/issue.net ]]; then
        head -1 /etc/issue.net
    else
        uname -s -r
    fi
}

# ── Obtener versión del OS ──
get_os_version() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${VERSION_ID}"
    else
        echo "desconocida"
    fi
}

# ── Obtener distribución base ──
get_os_family() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${ID_LIKE:-${ID}}"
    else
        echo "desconocida"
    fi
}

# ── Listar puertos activos TCP ──
# Utiliza 'ss' (moderno) en vez de 'lsof' (obsoleto para esto)
# Devuelve: PROCESO PUERTO (uno por línea, sin duplicados)
get_ports() {
    local filter="${1:-}"  # Filtro opcional por nombre de proceso

    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | awk 'NR>1 {
            split($4, a, ":");
            port = a[length(a)];
            match($0, /users:\(\("([^"]+)"/, proc);
            if (proc[1] != "" && port != "") {
                key = proc[1] " " port;
                if (!seen[key]++) print proc[1], port
            }
        }' | sort -u
    else
        # Fallback a lsof si ss no está disponible
        lsof -i tcp -P -n 2>/dev/null | grep LISTEN | awk '{
            split($9, a, ":");
            port = a[length(a)];
            key = $1 " " port;
            if (!seen[key]++) print $1, port
        }' | sort -u
    fi
}

# ── Verificar si un puerto está en uso ──
is_port_used() {
    local port="$1"
    ss -tlnp 2>/dev/null | grep -q ":${port}\b" && return 0 || return 1
}

# ── Verificar si un servicio/proceso está corriendo ──
is_running() {
    local name="$1"

    # Primero intentar systemctl
    if systemctl is-active --quiet "$name" 2>/dev/null; then
        return 0
    fi

    # Fallback a verificar procesos
    pgrep -x "$name" &>/dev/null && return 0

    # Verificar con nombre parcial
    pgrep -f "$name" &>/dev/null && return 0

    return 1
}

# ── Status de servicio como texto ──
service_status() {
    local name="$1"
    if is_running "$name"; then
        echo -e "${STATUS_ON}"
    else
        echo -e "${STATUS_OFF}"
    fi
}

# ── Controlar servicios (systemd-first) ──
service_ctl() {
    local action="$1"  # start, stop, restart, enable, disable
    local name="$2"

    if command -v systemctl &>/dev/null; then
        systemctl "$action" "$name" 2>/dev/null && return 0
    fi

    # Fallback a service / init.d
    case "$action" in
        start|stop|restart)
            service "$name" "$action" 2>/dev/null && return 0
            [[ -x "/etc/init.d/$name" ]] && "/etc/init.d/$name" "$action" 2>/dev/null && return 0
            ;;
    esac
    return 1
}

# ── Información del sistema ──
get_sysinfo() {
    local info_type="$1"

    case "$info_type" in
        cpu_model)
            grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs
            ;;
        cpu_cores)
            nproc 2>/dev/null || grep -c processor /proc/cpuinfo
            ;;
        cpu_usage)
            # Promedio de uso de CPU
            top -bn1 2>/dev/null | grep 'Cpu(s)' | awk '{print $2 + $4"%"}'
            ;;
        ram_total)
            free -h 2>/dev/null | awk '/Mem:/{print $2}'
            ;;
        ram_used)
            free -h 2>/dev/null | awk '/Mem:/{print $3}'
            ;;
        ram_free)
            free -h 2>/dev/null | awk '/Mem:/{print $4}'
            ;;
        ram_percent)
            free 2>/dev/null | awk '/Mem:/{printf "%.0f%%", $3/$2 * 100}'
            ;;
        uptime)
            uptime -p 2>/dev/null || uptime
            ;;
        hostname)
            hostname
            ;;
        kernel)
            uname -r
            ;;
        arch)
            uname -m
            ;;
    esac
}

# ── Contar usuarios SSH registrados ──
count_ssh_users() {
    grep -c '/home' /etc/passwd 2>/dev/null || echo "0"
}

# ── Verificar si un comando existe ──
has_command() {
    command -v "$1" &>/dev/null
}

# ── Instalar paquete si no existe ──
ensure_package() {
    local pkg="$1"
    if ! dpkg -s "$pkg" &>/dev/null; then
        apt-get install -y "$pkg" > /dev/null 2>&1
    fi
}

# ── Matar procesos por nombre ──
kill_by_name() {
    local name="$1"
    local pids
    pids=$(pgrep -f "$name" 2>/dev/null)

    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -9 2>/dev/null
        return 0
    fi
    return 1
}

# ── Deshabilitar IPv6 ──
disable_ipv6() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1 > /dev/null 2>&1
}
