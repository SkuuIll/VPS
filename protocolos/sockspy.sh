#!/bin/bash
# ============================================================
# VPS — Socks Python (HTTP Custom Proxy)
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh" 2>/dev/null || source "/etc/VPS/lib/config.sh" 2>/dev/null || true
check_root

# Verificar Python 3
if ! command -v python3 &> /dev/null; then
    run_with_spinner "Instalando Python 3..." "apt-get update -q && apt-get install -y python3"
fi

PROXY_DIR="/etc/VPS/protocolos"
PROXY_FILE="${PROXY_DIR}/proxy3.py"
SERVICE_DIR="/etc/systemd/system"

# ── Generar script de Python 3 ──
generate_python_script() {
    cat > "$PROXY_FILE" << 'EOF'
#!/usr/bin/env python3
import socket
import threading
import sys

def handle_client(client_socket, target_host, target_port, response_header):
    try:
        request = client_socket.recv(4096).decode('utf-8', 'ignore')
        if not request:
            client_socket.close()
            return
            
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((target_host, target_port))
        
        # Enviar respuesta de éxito configurada (Ej: 200 Connection Established)
        if "CONNECT" in request or "GET" in request or "POST" in request:
            response = f"HTTP/1.1 {response_header}\r\n\r\n"
            client_socket.send(response.encode('utf-8'))
        else:
            target_socket.send(request.encode('utf-8'))
            
        # Tunel
        threading.Thread(target=forward, args=(client_socket, target_socket)).start()
        threading.Thread(target=forward, args=(target_socket, client_socket)).start()
        
    except Exception as e:
        client_socket.close()

def forward(source, destination):
    try:
        while True:
            data = source.recv(4096)
            if not data:
                break
            destination.send(data)
    except:
        pass
    finally:
        source.close()
        destination.close()

def main():
    if len(sys.argv) < 4:
        print("Uso: proxy3.py [Puerto Listen] [Puerto Destino] [Respuesta HTTP]")
        sys.exit(1)
        
    listen_port = int(sys.argv[1])
    target_port = int(sys.argv[2])
    response_header = sys.argv[3].replace('_', ' ')
    
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind(('0.0.0.0', listen_port))
        server.listen(100)
        print(f"Proxy Listen: {listen_port}, Target: 127.0.0.1:{target_port}")
        
        while True:
            client, addr = server.accept()
            threading.Thread(target=handle_client, args=(client, '127.0.0.1', target_port, response_header)).start()
            
    except Exception as e:
        print(f"Error: {e}")
        server.close()

if __name__ == '__main__':
    main()
EOF
    chmod +x "$PROXY_FILE"
}

start_socks() {
    ui_msg_green "INSTALADOR SOCKS PYTHON"
    ui_bar
    
    local listen_port
    listen_port=$(ui_input "Puerto de Escucha (Listen)" "^[0-9]+$" "80")
    
    if is_port_used "$listen_port"; then
        ui_error "El puerto ${listen_port} ya está en uso."
        return 1
    fi
    
    local target_port
    target_port=$(ui_input "Puerto Destino SSH (Ej: 22, 443, etc)" "^[0-9]+$" "22")
    
    if ! is_port_used "$target_port"; then
        ui_warn "El puerto destino ${target_port} no parece estar activo. ¿Continuar de todos modos?"
        if ! ui_confirm "¿Continuar? "; then
            return 1
        fi
    fi
    
    local response
    response=$(ui_input "Respuesta HTTP (Ej: 200 OK, 101 Switching Protocols)" "" "200 Connection Established")
    local response_safe=$(echo "$response" | tr ' ' '_')
    
    generate_python_script
    
    local srv_name="sockspy-${listen_port}.service"
    
    cat > "${SERVICE_DIR}/${srv_name}" << EOF
[Unit]
Description=Socks Python Proxy (Port $listen_port)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PROXY_DIR}
ExecStart=/usr/bin/python3 ${PROXY_FILE} ${listen_port} ${target_port} "${response_safe}"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${srv_name}" >/dev/null 2>&1
    systemctl start "${srv_name}"
    
    if systemctl is-active --quiet "${srv_name}"; then
        ui_success "Socks Python iniciado en puerto ${BGREEN}${listen_port}${RST} -> Destino: ${target_port}"
        echo -e "  ${BWHITE}Respuesta HTTP:${RST} ${BCYAN}${response}${RST}"
    else
        ui_error "Error al iniciar el servicio Socks."
    fi
    ui_bar
}

stop_socks() {
    ui_msg_green "DETENER SOCKS PYTHON"
    ui_bar
    
    # Listar servicios activos
    local active_services=$(systemctl list-units --type=service --state=running | grep sockspy- | awk '{print $1}')
    
    if [[ -z "$active_services" ]]; then
        ui_warn "No hay ningún puente Socks Python activo."
        return
    fi
    
    echo -e "  ${BWHITE}Puertos activos:${RST}"
    for srv in $active_services; do
        local p=$(echo "$srv" | grep -o -E '[0-9]+')
        echo -e "   - Puerto ${BCYAN}${p}${RST}"
    done
    ui_bar
    
    if ui_confirm "¿Detener TODOS los Socks Python?"; then
        for srv in $active_services; do
            systemctl stop "$srv"
            systemctl disable "$srv" >/dev/null 2>&1
            rm -f "${SERVICE_DIR}/${srv}"
        done
        systemctl daemon-reload
        ui_success "Todos los procesos de Socks Python han sido detenidos y eliminados."
    fi
    ui_bar
}

main() {
    while true; do
        ui_clear
        ui_bar
        ui_title_small
        echo -e "${THEME_HEADER}         PROXY SOCKS PYTHON${RST}"
        ui_bar
        
        local active_count=$(systemctl list-units --type=service --state=running | grep -c sockspy-)
        local st
        
        if [[ $active_count -gt 0 ]]; then
            st="${STATUS_ON} ($active_count)"
        else
            st="${STATUS_OFF}"
        fi
        
        echo -e " ${BCYAN}ℹ${RST} Este proxy le permite recibir inyecciones HTTP"
        echo -e "   (Payloads) y redirigirlas a su puerto SSH."
        ui_bar
        
        ui_menu_item 1 "Nuevo Proxy Socks Python (Listen)" "$st"
        ui_menu_item 2 "Detener / Eliminar Proxys Socks"
        ui_bar
        ui_menu_back 0
        ui_bar
        
        local sel
        sel=$(ui_select 2)
        case "$sel" in
            1)
                start_socks
                ui_pause
                ;;
            2)
                stop_socks
                ui_pause
                ;;
            0) return ;;
        esac
    done
}

main