#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../lib/config.sh"
check_root

main() {
    ui_clear
    ui_bar
    ui_title_small
    echo -e "${THEME_HEADER}     AUTENTICACION PROXY SQUID${RST}"
    ui_bar

    local squid_conf=""
    [[ -f /etc/squid/squid.conf ]] && squid_conf="/etc/squid/squid.conf"
    [[ -f /etc/squid3/squid.conf ]] && squid_conf="/etc/squid3/squid.conf"

    if [[ -z "$squid_conf" ]]; then
        ui_error "Squid no esta instalado"
        return 1
    fi

    ui_menu_item 1 "Activar autenticacion"
    ui_menu_item 2 "Agregar usuario"
    ui_menu_item 3 "Eliminar usuario"
    ui_menu_item 4 "Listar usuarios"
    ui_menu_item 5 "Desactivar autenticacion"
    ui_bar
    ui_menu_back 0
    ui_bar

    local sel
    sel=$(ui_select 5)
    local passwd_file="/etc/squid/passwd"

    case "$sel" in
        1)
            ensure_package apache2-utils
            backup_file "$squid_conf"
            local user pass
            user=$(ui_input "Usuario" "^[a-zA-Z0-9_]+$")
            read -rsp " Password: " pass; echo ""
            htpasswd -cb "$passwd_file" "$user" "$pass" 2>/dev/null
            if ! grep -q "auth_param basic" "$squid_conf"; then
                sed -i "/^http_access/i auth_param basic program /usr/lib/squid/basic_ncsa_auth ${passwd_file}" "$squid_conf"
                sed -i "/^http_access/i acl authenticated proxy_auth REQUIRED" "$squid_conf"
                sed -i "s/^http_access allow all/http_access allow authenticated/" "$squid_conf"
            fi
            service_ctl restart squid 2>/dev/null; service_ctl restart squid3 2>/dev/null
            ui_success "Autenticacion configurada"
            ;;
        2)
            ensure_package apache2-utils
            local user pass
            user=$(ui_input "Nuevo usuario" "^[a-zA-Z0-9_]+$")
            read -rsp " Password: " pass; echo ""
            htpasswd -b "$passwd_file" "$user" "$pass" 2>/dev/null
            ui_success "Usuario agregado"
            ;;
        3)
            local user
            user=$(ui_input "Usuario a eliminar" "^[a-zA-Z0-9_]+$")
            htpasswd -D "$passwd_file" "$user" 2>/dev/null
            ui_success "Usuario eliminado"
            ;;
        4)
            if [[ -f "$passwd_file" ]]; then
                ui_step "Usuarios:"; cut -d: -f1 "$passwd_file"
            else
                ui_warn "No hay usuarios"
            fi
            ;;
        5)
            backup_file "$squid_conf"
            sed -i '/auth_param/d' "$squid_conf"
            sed -i '/acl authenticated/d' "$squid_conf"
            sed -i 's/http_access allow authenticated/http_access allow all/' "$squid_conf"
            service_ctl restart squid 2>/dev/null; service_ctl restart squid3 2>/dev/null
            ui_success "Autenticacion desactivada"
            ;;
        0) return ;;
    esac
    ui_bar
}

main
