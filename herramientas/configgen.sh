#!/bin/bash
# ============================================================
# VPS-MX -- Generador de Configs para Clientes
# ============================================================
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

SERVER_IP=$(get_ip)

# -- Generar payload HTTP Injector --
gen_http_injector() {
    ui_bar
    local port method host
    port=$(ui_input "Puerto del proxy (ej: 8080, 80)" "^[0-9]+$" "8080")
    echo -e "  ${BWHITE}Metodos: GET, CONNECT, POST, HEAD${RST}"
    method=$(ui_input "Metodo HTTP" "^(GET|CONNECT|POST|HEAD)$" "CONNECT")
    host=$(ui_input "Host/SNI (ej: www.google.com)" ".+" "www.google.com")

    local output="/root/HTTP-Injector-${port}.ehi"

    cat > "$output" << EOF
[proxy]
proxy_type=0
ip=${SERVER_IP}
port=${port}
EOF

    if [[ "$method" == "CONNECT" ]]; then
        cat >> "$output" << EOF

[payload]
payload_mode=0
payload=${method} [host_port] HTTP/1.1[crlf]Host: ${host}[crlf]Connection: Keep-Alive[crlf][crlf]
EOF
    else
        cat >> "$output" << EOF

[payload]
payload_mode=0
payload=${method} http://${host}/ HTTP/1.1[crlf]Host: ${host}[crlf]Connection: Keep-Alive[crlf][crlf]
EOF
    fi

    cat >> "$output" << EOF

[ssh]
ssh_ip=${SERVER_IP}
ssh_port=22

[dns]
dns_mode=0
dns_address=8.8.8.8
dns_port=53
EOF

    ui_success "Config HTTP Injector generada"
    echo -e "  ${BWHITE}Archivo:${RST} ${BCYAN}${output}${RST}"
    ui_bar
}

# -- Generar archivo .ovpn --
gen_openvpn() {
    ui_bar

    local ovpn_conf="/etc/openvpn/server.conf"
    if [[ ! -f "$ovpn_conf" ]]; then
        ui_error "OpenVPN no esta instalado"
        return 1
    fi

    local port proto
    port=$(grep "^port " "$ovpn_conf" | awk '{print $2}')
    proto=$(grep "^proto " "$ovpn_conf" | awk '{print $2}')

    local ca_cert="/etc/openvpn/ca.crt"
    local client_cert="/etc/openvpn/client.crt"
    local client_key="/etc/openvpn/client.key"
    local ta_key="/etc/openvpn/ta.key"

    local output="/root/VPS-MX-client.ovpn"

    cat > "$output" << EOF
client
dev tun
proto ${proto:-tcp}
remote ${SERVER_IP} ${port:-1194}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
verb 3
auth-user-pass
EOF

    # Agregar certificados si existen
    if [[ -f "$ca_cert" ]]; then
        echo "<ca>" >> "$output"
        cat "$ca_cert" >> "$output"
        echo "</ca>" >> "$output"
    fi

    if [[ -f "$ta_key" ]]; then
        echo "key-direction 1" >> "$output"
        echo "<tls-auth>" >> "$output"
        cat "$ta_key" >> "$output"
        echo "</tls-auth>" >> "$output"
    fi

    ui_success "Config OpenVPN generada"
    echo -e "  ${BWHITE}Archivo:${RST}   ${BCYAN}${output}${RST}"
    echo -e "  ${BWHITE}Servidor:${RST}  ${BGREEN}${SERVER_IP}:${port:-1194} (${proto:-tcp})${RST}"
    ui_bar
}

# -- Generar config SSH/SSL para apps --
gen_ssh_config() {
    ui_bar
    local ssh_port ssl_port payload_host

    ssh_port=$(ui_input "Puerto SSH" "^[0-9]+$" "22")
    ssl_port=$(ui_input "Puerto SSL (0 si no hay)" "^[0-9]+$" "443")
    payload_host=$(ui_input "Host/SNI" ".+" "www.google.com")

    local output="/root/SSH-Config-${ssh_port}.txt"

    cat > "$output" << EOF
============================================
  CONFIGURACION SSH/SSL - VPS-MX
============================================
  Servidor:  ${SERVER_IP}
  SSH Port:  ${ssh_port}
  SSL Port:  ${ssl_port}
  SNI/Host:  ${payload_host}
============================================

--- Para HTTP Injector ---
  Tipo: SSH + SSL
  IP SSH: ${SERVER_IP}
  Puerto SSH: ${ssh_port}
  Puerto SSL: ${ssl_port}

--- Para HTTP Custom ---
  Proxy: ${SERVER_IP}:${ssl_port}
  Metodo: CONNECT
  Payload: CONNECT [host_port] HTTP/1.1\r\nHost: ${payload_host}\r\n\r\n

--- Para EveryProxy ---
  IP: ${SERVER_IP}
  Puerto: ${ssl_port}
  Tipo: SSL

--- Terminal SSH ---
  ssh -p ${ssh_port} usuario@${SERVER_IP}
============================================
EOF

    ui_success "Config SSH generada"
    echo -e "  ${BWHITE}Archivo:${RST} ${BCYAN}${output}${RST}"
    ui_bar
}

# -- Generar config V2Ray/VMess --
gen_v2ray_config() {
    ui_bar

    local v2ray_conf="/etc/v2ray/config.json"
    [[ ! -f "$v2ray_conf" ]] && v2ray_conf="/usr/local/etc/v2ray/config.json"

    if [[ ! -f "$v2ray_conf" ]]; then
        ui_error "V2Ray no esta instalado"
        return 1
    fi

    local uuid port
    uuid=$(grep -o '"id": *"[^"]*"' "$v2ray_conf" | head -1 | cut -d'"' -f4)
    port=$(grep -o '"port": *[0-9]*' "$v2ray_conf" | head -1 | grep -o '[0-9]*')

    local output="/root/V2Ray-VMess.json"

    cat > "$output" << EOF
{
  "v": "2",
  "ps": "VPS-MX Server",
  "add": "${SERVER_IP}",
  "port": "${port:-443}",
  "id": "${uuid:-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "/",
  "tls": "",
  "sni": "",
  "alpn": ""
}
EOF

    # Generar link vmess://
    local vmess_json='{"v":"2","ps":"VPS-MX","add":"'${SERVER_IP}'","port":"'${port:-443}'","id":"'${uuid}'","aid":"0","net":"ws","type":"none","path":"/"}'
    local vmess_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"

    ui_success "Config V2Ray generada"
    echo -e "  ${BWHITE}Archivo:${RST}  ${BCYAN}${output}${RST}"
    echo -e "  ${BWHITE}UUID:${RST}     ${BGREEN}${uuid:-N/A}${RST}"
    echo -e "  ${BWHITE}Puerto:${RST}   ${BGREEN}${port:-N/A}${RST}"
    echo -e "\n  ${BWHITE}Link VMess:${RST}"
    echo -e "  ${BCYAN}${vmess_link}${RST}"
    ui_bar
}

# -- Menu --
main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}    GENERADOR DE CONFIGS PARA CLIENTES${RST}"
    ui_bar
    echo -e "  ${BWHITE}Servidor:${RST} ${BCYAN}${SERVER_IP}${RST}"
    ui_bar

    ui_menu_item 1 "HTTP Injector (.ehi)"
    ui_menu_item 2 "OpenVPN (.ovpn)"
    ui_menu_item 3 "SSH/SSL Config (texto)"
    ui_menu_item 4 "V2Ray/VMess (JSON + link)"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 4)

    case "$sel" in
        1) gen_http_injector ;;
        2) gen_openvpn ;;
        3) gen_ssh_config ;;
        4) gen_v2ray_config ;;
        0) return ;;
    esac
}

main
