# VPS Panel v2.0

Panel de administracion VPS para tuneles, VPN y proxies.

## Instalar

```bash
apt update; apt upgrade -y; wget https://raw.githubusercontent.com/SkuuIll/VPS/main/instalar && chmod +x instalar && ./instalar
```

Despues de instalar:

```bash
VPS
```

o

```bash
menu
```

## Funciones

- **Cuentas SSH/SSL/Dropbear** - Crear, eliminar, renovar
- **Expiracion automatica** - Bloqueo de cuentas al vencer
- **Monitor en tiempo real** - Usuarios conectados, IPs, tiempos
- **Dashboard** - CPU, RAM, disco, trafico, servicios
- **Backup/Restore** - Exportar e importar toda la config
- **Limitador de banda** - Control por usuario con tc
- **Generador de configs** - HTTP Injector, OpenVPN, V2Ray, SSH/SSL
- **Protocolos** - Dropbear, Stunnel, Squid, OpenVPN, V2Ray, Shadowsocks, BadVPN, UDP Custom
- **Herramientas** - Firewall, Fail2Ban, DNS, TCP Speed, puertos, limpieza

## Compatibilidad

- Ubuntu 22.04
- Ubuntu 24.04

## Estructura

```
lib/             Librerias compartidas
services/        Servicios systemd
herramientas/    Herramientas y configuracion
protocolos/      Instaladores de protocolos
controlador/     Base de datos de usuarios
install.sh       Instalador
uninstall.sh     Desinstalador
menu             Menu principal
```

## Desinstalar

```bash
sudo bash /etc/VPS/uninstall.sh
```

## Actualizar

```bash
cd /root/VPS && git pull && sudo bash install.sh --force
```
