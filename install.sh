#!/bin/bash
# ============================================================
# VPS — Instalador Principal v2.0
# ============================================================
# Compatibilidad: Ubuntu 22.04 / 24.04
# Uso: bash install.sh [--dry-run] [--force]
# Comando tras instalar: VPS
# ============================================================
set -euo pipefail

# ── Colores básicos (antes de cargar lib) ──
RST='\033[0m'
BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'
BMAGENTA='\033[1;35m'

# ── Variables ──
INSTALL_DIR="/etc/VPS"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false
FORCE=false

# ── Parse args ──
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
        --help|-h)
            echo "Uso: bash install.sh [--dry-run] [--force]"
            echo "  --dry-run  Simular instalación sin hacer cambios"
            echo "  --force    Forzar reinstalación sobre instalación existente"
            exit 0
            ;;
    esac
done

# ── Funciones de mensajes ──
msg_ok()   { echo -e " ${BGREEN}✔${RST} $*"; }
msg_fail() { echo -e " ${BRED}✘${RST} $*"; }
msg_warn() { echo -e " ${BYELLOW}⚠${RST} $*"; }
msg_info() { echo -e " ${BCYAN}ℹ${RST} $*"; }
msg_step() { echo -e " ${BMAGENTA}▸${RST} ${BWHITE}$*${RST}"; }

bar() {
    printf "${BYELLOW}"
    printf '%60s' '' | tr ' ' '━'
    printf "${RST}\n"
}

banner() {
    clear
    echo ""
    echo -e "${BCYAN}"
    echo -e "  ██╗   ██╗██████╗ ███████╗    ███╗   ███╗██╗  ██╗"
    echo -e "  ██║   ██║██╔══██╗██╔════╝    ████╗ ████║╚██╗██╔╝"
    echo -e "  ██║   ██║██████╔╝███████╗    ██╔████╔██║ ╚███╔╝ "
    echo -e "  ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║ ██╔██╗ "
    echo -e "   ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║██╔╝ ██╗"
    echo -e "    ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝"
    echo -e "${RST}"
    echo -e "${BYELLOW}  ━━━━━━━━━ INSTALADOR v2.0 ━━━━━━━━━${RST}"
    echo ""
    bar
}

# ── Verificaciones previas ──
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_fail "Este instalador debe ejecutarse como ${BRED}root${RST}"
        echo -e "   Ejecuta: ${BWHITE}sudo bash install.sh${RST}"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        msg_fail "No se pudo detectar el sistema operativo"
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        msg_warn "Sistema detectado: ${BWHITE}${PRETTY_NAME}${RST}"
        msg_warn "Este instalador está optimizado para Ubuntu 22/24"
        if [[ "$FORCE" != "true" ]]; then
            echo -ne " ¿Continuar de todos modos? [s/N]: "
            read -r answer
            [[ "$answer" != @(s|S|y|Y) ]] && exit 1
        fi
        return
    fi

    local ver="${VERSION_ID%%.*}"
    if (( ver < 22 )); then
        msg_fail "Ubuntu ${VERSION_ID} no es soportado"
        msg_info "Versiones soportadas: Ubuntu 22.04, 24.04"
        exit 1
    fi

    msg_ok "Sistema: ${BWHITE}${PRETTY_NAME}${RST}"
}

check_existing() {
    if [[ -d "$INSTALL_DIR" && "$FORCE" != "true" ]]; then
        msg_warn "VPS ya está instalado en ${BWHITE}${INSTALL_DIR}${RST}"
        echo -ne " ¿Reinstalar? Esto creará un backup [s/N]: "
        read -r answer
        if [[ "$answer" == @(s|S|y|Y) ]]; then
            local backup_name="VPS-backup-$(date +%Y%m%d_%H%M%S)"
            cp -r "$INSTALL_DIR" "/root/${backup_name}"
            msg_ok "Backup creado: ${BWHITE}/root/${backup_name}${RST}"
        else
            exit 0
        fi
    fi
}

# ── Instalar dependencias ──
install_deps() {
    msg_step "Instalando dependencias..."

    local packages=(
        python3
        screen
        curl
        wget
        net-tools
        bc
        jq
        openssl
        cron
        unzip
    )

    if $DRY_RUN; then
        msg_info "[dry-run] apt-get install ${packages[*]}"
        return
    fi

    apt-get update -qq > /dev/null 2>&1 || true

    local installed=0
    local failed=0
    for pkg in "${packages[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            continue
        fi
        if apt-get install -y -qq "$pkg" > /dev/null 2>&1; then
            (( installed++ ))
        else
            msg_warn "No se pudo instalar: $pkg"
            (( failed++ ))
        fi
    done

    if (( installed > 0 )); then
        msg_ok "${installed} paquetes instalados"
    fi
    if (( failed > 0 )); then
        msg_warn "${failed} paquetes no se pudieron instalar"
    fi
    msg_ok "Dependencias verificadas"
}

# ── Copiar archivos ──
install_files() {
    msg_step "Instalando archivos del panel..."

    if $DRY_RUN; then
        msg_info "[dry-run] Copiar ${SRC_DIR} → ${INSTALL_DIR}"
        return
    fi

    # Crear estructura de directorios
    mkdir -p "${INSTALL_DIR}"/{lib,controlador,herramientas,protocolos,services,backups,logs}

    # Copiar librería core
    cp -f "${SRC_DIR}"/lib/*.sh "${INSTALL_DIR}/lib/"

    # Copiar menú principal
    cp -f "${SRC_DIR}/menu" "${INSTALL_DIR}/menu"

    # Copiar herramientas
    if [[ -d "${SRC_DIR}/herramientas" ]]; then
        cp -f "${SRC_DIR}"/herramientas/*.sh "${INSTALL_DIR}/herramientas/" 2>/dev/null || true
        cp -f "${SRC_DIR}"/herramientas/*.py "${INSTALL_DIR}/herramientas/" 2>/dev/null || true
    fi

    # Copiar protocolos
    if [[ -d "${SRC_DIR}/protocolos" ]]; then
        cp -f "${SRC_DIR}"/protocolos/*.sh "${INSTALL_DIR}/protocolos/" 2>/dev/null || true
        cp -f "${SRC_DIR}"/protocolos/*.py "${INSTALL_DIR}/protocolos/" 2>/dev/null || true
    fi

    # Copiar servicios systemd
    if [[ -d "${SRC_DIR}/services" ]]; then
        cp -f "${SRC_DIR}"/services/*.service "${INSTALL_DIR}/services/" 2>/dev/null || true
    fi

    # Datos existentes (preservar si existen)
    [[ -f "${SRC_DIR}/MEUIPvps" ]]    && cp -n "${SRC_DIR}/MEUIPvps" "${INSTALL_DIR}/"

    # Copiar usercodes (preservar existente)
    if [[ -d "${SRC_DIR}/controlador" ]]; then
        cp -n "${SRC_DIR}"/controlador/* "${INSTALL_DIR}/controlador/" 2>/dev/null || true
    fi

    msg_ok "Archivos instalados"
}

# ── Configurar permisos ──
set_permissions() {
    msg_step "Configurando permisos..."

    if $DRY_RUN; then
        msg_info "[dry-run] chmod +x sobre scripts"
        return
    fi

    # Hacer ejecutables los scripts .sh y el menú
    chmod +x "${INSTALL_DIR}/menu"
    find "${INSTALL_DIR}/lib" -name "*.sh" -exec chmod +x {} \;
    find "${INSTALL_DIR}/herramientas" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    find "${INSTALL_DIR}/protocolos" -name "*.sh" -exec chmod +x {} \; 2>/dev/null

    # Permisos seguros para datos (NO 777)
    chmod 700 "${INSTALL_DIR}/controlador" 2>/dev/null || true

    msg_ok "Permisos configurados"
}

# ── Crear comando CLI ──
create_command() {
    msg_step "Creando comando ${BWHITE}VPS${RST}..."

    if $DRY_RUN; then
        msg_info "[dry-run] Crear /usr/local/bin/VPS"
        return
    fi

    # Crear el comando principal: VPS
    cat > /usr/local/bin/VPS << 'SCRIPT'
#!/bin/bash
exec /etc/VPS/menu "$@"
SCRIPT
    chmod +x /usr/local/bin/VPS

    # Aliases para conveniencia
    ln -sf /usr/local/bin/VPS /usr/local/bin/vps 2>/dev/null || true
    ln -sf /usr/local/bin/VPS /usr/local/bin/menu 2>/dev/null || true

    # Limpiar comandos viejos
    rm -f /usr/bin/vps /usr/bin/VPS /bin/VPS /bin/menu 2>/dev/null || true

    msg_ok "Comando creado: escribe ${BGREEN}VPS${RST} para entrar al panel"
}

# ── Instalar servicios systemd ──
install_services() {
    msg_step "Configurando servicios systemd..."

    if $DRY_RUN; then
        msg_info "[dry-run] Instalar .service en /etc/systemd/system/"
        return
    fi

    # BadVPN UDPGW service
    if [[ -f "${INSTALL_DIR}/services/badvpn-udpgw.service" ]]; then
        cp -f "${INSTALL_DIR}/services/badvpn-udpgw.service" /etc/systemd/system/
        systemctl daemon-reload 2>/dev/null || true
        msg_ok "Servicio badvpn-udpgw instalado"
    fi

    # Monitor service
    if [[ -f "${INSTALL_DIR}/services/vps-monitor.service" ]]; then
        cp -f "${INSTALL_DIR}/services/vps-monitor.service" /etc/systemd/system/
        systemctl daemon-reload 2>/dev/null || true
        msg_ok "Servicio vps-monitor instalado"
    fi
}

# ── Deshabilitar IPv6 (persistente) ──
configure_sysctl() {
    msg_step "Configurando parámetros del sistema..."

    if $DRY_RUN; then
        msg_info "[dry-run] Configurar sysctl IPv6"
        return
    fi

    local sysctl_file="/etc/sysctl.d/99-vps.conf"
    cat > "$sysctl_file" << 'EOF'
# VPS: Deshabilitar IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p "$sysctl_file" > /dev/null 2>&1 || true

    msg_ok "Parámetros del sistema configurados"
}

# ── Resumen final ──
show_summary() {
    echo ""
    bar
    echo -e "${BGREEN}  ✔ INSTALACIÓN COMPLETADA${RST}"
    bar
    echo ""
    echo -e "  ${BWHITE}Comando:${RST}     ${BGREEN}VPS${RST}"
    echo -e "  ${BWHITE}Directorio:${RST}  ${BCYAN}${INSTALL_DIR}${RST}"
    echo -e "  ${BWHITE}Versión:${RST}     ${BCYAN}2.0.0${RST}"
    echo -e "  ${BWHITE}OS:${RST}          ${BCYAN}$(source /etc/os-release && echo "$PRETTY_NAME")${RST}"
    echo ""
    echo -e "  ${BYELLOW}Para acceder al panel:${RST}"
    echo -e "  ${BWHITE}┌──────────────────────────────┐${RST}"
    echo -e "  ${BWHITE}│  ${BGREEN}VPS${BWHITE}   o   ${BGREEN}menu${BWHITE}              │${RST}"
    echo -e "  ${BWHITE}└──────────────────────────────┘${RST}"
    echo ""
    bar
}

# ══════════════════════════════════════
# MAIN
# ══════════════════════════════════════
main() {
    banner
    check_root

    if $DRY_RUN; then
        msg_warn "MODO SIMULACIÓN — No se harán cambios"
        bar
    fi

    check_os
    check_existing
    echo ""
    install_deps
    install_files
    set_permissions
    create_command
    install_services
    configure_sysctl
    show_summary
}

main "$@"
