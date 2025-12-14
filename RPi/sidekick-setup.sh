#!/bin/bash
# =============================================================================
# SIDEKICK Setup Script (Unified Install & Update)
# =============================================================================
# Dieses Script erkennt automatisch ob SIDEKICK bereits installiert ist:
#   - Falls NEIN: Vollständige Installation
#   - Falls JA:   Update auf neueste Version
#
# Verwendung:
#   sudo bash sidekick-setup.sh              → Stabiles Release
#   sudo bash sidekick-setup.sh --pre        → Inklusive Pre-Releases
#   sudo bash sidekick-setup.sh --force      → Erzwingt Neuinstallation
#   sudo bash sidekick-setup.sh --help       → Zeigt Hilfe
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Konfiguration
# -----------------------------------------------------------------------------
SCRIPT_VERSION="2.0.0"
GITHUB_REPO="Mixality/sidekick-scratch-extension-development"

# Farben fuer Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Standard-Optionen
INCLUDE_PRERELEASE=false
FORCE_INSTALL=false
SHOW_HELP=false

# -----------------------------------------------------------------------------
# Argumente verarbeiten
# -----------------------------------------------------------------------------
for arg in "$@"; do
    case $arg in
        --pre|--dev|--test)
            INCLUDE_PRERELEASE=true
            ;;
        --force|-f)
            FORCE_INSTALL=true
            ;;
        --help|-h)
            SHOW_HELP=true
            ;;
        *)
            echo -e "${RED}Unbekannte Option: $arg${NC}"
            echo "Verwende --help für Hilfe"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Hilfe anzeigen
# -----------------------------------------------------------------------------
if [ "$SHOW_HELP" = true ]; then
    echo ""
    echo -e "${CYAN}SIDEKICK Setup Script v$SCRIPT_VERSION${NC}"
    echo "======================================"
    echo ""
    echo "Verwendung:"
    echo "  sudo bash sidekick-setup.sh [OPTIONEN]"
    echo ""
    echo "Optionen:"
    echo "  --pre, --dev, --test    Installiert auch Pre-Releases (Test-Versionen)"
    echo "  --force, -f             Erzwingt Neuinstallation auch wenn aktuell"
    echo "  --help, -h              Zeigt diese Hilfe"
    echo ""
    echo "Beispiele:"
    echo "  sudo bash sidekick-setup.sh              Neuestes stabiles Release"
    echo "  sudo bash sidekick-setup.sh --pre        Neuestes Release (inkl. Test)"
    echo "  sudo bash sidekick-setup.sh --force      Erzwingt komplette Neuinstallation"
    echo ""
    echo "Pre-Release Tags: v1.0.1-test1, v1.0.1-dev, v1.0.1-beta, v1.0.1-alpha"
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# Funktionen
# -----------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}==============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}==============================================${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}[$1] $2${NC}"
}

print_success() {
    echo -e "${GREEN}   ✓ $1${NC}"
}

print_error() {
    echo -e "${RED}   ✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}   ℹ $1${NC}"
}

get_latest_release() {
    if [ "$INCLUDE_PRERELEASE" = true ]; then
        # Alle Releases (inklusive Pre-Releases), erstes = neuestes
        curl -sSL "https://api.github.com/repos/$GITHUB_REPO/releases" 2>/dev/null | \
            grep -m 1 '"tag_name":' | \
            sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
    else
        # Nur stabiles Release
        curl -sSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null | \
            grep '"tag_name":' | \
            sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
    fi
}

get_current_version() {
    if [ -f "$SIDEKICK_DIR/VERSION" ]; then
        cat "$SIDEKICK_DIR/VERSION"
    else
        echo ""
    fi
}

generate_hostname() {
    # Generiert einen eindeutigen Hostnamen basierend auf MAC-Adresse
    # Format: sidekick-XXXXXX (6 Zeichen, lowercase)
    local mac_hash=$(cat /sys/class/net/*/address 2>/dev/null | head -1 | md5sum | cut -c1-6)
    if [ -z "$mac_hash" ]; then
        # Fallback: Seriennummer
        mac_hash=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2 | tail -c 7 | tr '[:upper:]' '[:lower:]')
    fi
    if [ -z "$mac_hash" ]; then
        # Fallback: Random
        mac_hash=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 6)
    fi
    echo "sidekick-$mac_hash"
}

# -----------------------------------------------------------------------------
# Root-Check
# -----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Fehler: Bitte als root ausführen:${NC}"
    echo "  sudo bash sidekick-setup.sh"
    exit 1
fi

# -----------------------------------------------------------------------------
# Benutzer und Pfade ermitteln
# -----------------------------------------------------------------------------
ACTUAL_USER="${SUDO_USER:-pi}"
USER_HOME=$(eval echo ~$ACTUAL_USER)
SIDEKICK_DIR="$USER_HOME/Sidekick"
WEBAPP_DIR="$SIDEKICK_DIR/sidekick"
PYTHON_DIR="$SIDEKICK_DIR/python"
SCRIPTS_DIR="$SIDEKICK_DIR/scripts"

# -----------------------------------------------------------------------------
# Modus erkennen: Installation oder Update?
# -----------------------------------------------------------------------------
CURRENT_VERSION=$(get_current_version)

if [ -z "$CURRENT_VERSION" ] || [ "$FORCE_INSTALL" = true ]; then
    IS_UPDATE=false
    if [ "$FORCE_INSTALL" = true ] && [ -n "$CURRENT_VERSION" ]; then
        MODE_TEXT="Neuinstallation (erzwungen)"
    else
        MODE_TEXT="Erstinstallation"
    fi
else
    IS_UPDATE=true
    MODE_TEXT="Update"
fi

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------
print_header "SIDEKICK Setup - $MODE_TEXT"

echo "Benutzer:        $ACTUAL_USER"
echo "Home:            $USER_HOME"
echo "SIDEKICK-Pfad:   $SIDEKICK_DIR"
if [ -n "$CURRENT_VERSION" ]; then
    echo "Installiert:     $CURRENT_VERSION"
fi
if [ "$INCLUDE_PRERELEASE" = true ]; then
    echo -e "Release-Modus:   ${YELLOW}Inklusive Pre-Releases${NC}"
else
    echo "Release-Modus:   Nur stabile Releases"
fi
echo ""

# -----------------------------------------------------------------------------
# 1. Neueste Version ermitteln
# -----------------------------------------------------------------------------
print_step "1/9" "Prüfe verfügbare Versionen..."

LATEST_VERSION=$(get_latest_release)
if [ -z "$LATEST_VERSION" ]; then
    print_error "Konnte neueste Version nicht ermitteln!"
    echo "      Prüfe deine Internetverbindung."
    exit 1
fi

print_success "Neueste Version: $LATEST_VERSION"

# Bei Update: Prüfen ob nötig
if [ "$IS_UPDATE" = true ] && [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && [ "$FORCE_INSTALL" = false ]; then
    echo ""
    echo -e "${GREEN}   Du hast bereits die neueste Version!${NC}"
    echo ""
    read -p "   Trotzdem neu installieren? (j/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        echo "   Abgebrochen."
        exit 0
    fi
fi

# -----------------------------------------------------------------------------
# 2. Bei Erstinstallation: Benutzer fragen
# -----------------------------------------------------------------------------
if [ "$IS_UPDATE" = false ]; then
    echo ""
    read -p "Fortfahren mit Installation? (J/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Abgebrochen."
        exit 1
    fi
fi

# =============================================================================
# CLEANUP: Alte Services und Prozesse stoppen
# =============================================================================
print_step "2/9" "Räume alte Installation auf..."

# Liste aller bekannten SIDEKICK-Services (alte und neue Namen)
KNOWN_SERVICES=(
    "sidekick-webapp"
    "sidekick-sensors"
    "sidekick-dashboard"
    "sidekick-kiosk"
    "sidekick-http"
    "sidekick-scratch"
)

# Services stoppen und deaktivieren
for service in "${KNOWN_SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        systemctl stop "$service" 2>/dev/null || true
        print_info "Gestoppt: $service"
    fi
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        systemctl disable "$service" 2>/dev/null || true
    fi
done

# Alte Ports freigeben (8000, 8080 - die alten Ports)
OLD_PORTS=(8000 8080)
for port in "${OLD_PORTS[@]}"; do
    # Finde Prozesse die auf alten Ports lauschen und beende sie
    OLD_PIDS=$(lsof -t -i:$port 2>/dev/null || true)
    if [ -n "$OLD_PIDS" ]; then
        for pid in $OLD_PIDS; do
            # Nur beenden wenn es ein Python http.server oder ähnliches ist
            PROC_NAME=$(ps -p $pid -o comm= 2>/dev/null || true)
            if [[ "$PROC_NAME" == *"python"* ]]; then
                kill $pid 2>/dev/null || true
                print_info "Prozess auf Port $port beendet (PID: $pid)"
            fi
        done
    fi
done

# Alte Service-Dateien die nicht mehr gebraucht werden können entfernt werden
# (aber wir überschreiben sie sowieso gleich, also nur zur Sicherheit)
systemctl daemon-reload

print_success "Cleanup abgeschlossen"

# =============================================================================
# NUR BEI ERSTINSTALLATION: System-Setup
# =============================================================================
if [ "$IS_UPDATE" = false ]; then

    # -------------------------------------------------------------------------
    # 3. Pakete installieren
    # -------------------------------------------------------------------------
    print_step "3/9" "Installiere benötigte Pakete..."

    apt-get update -qq
    apt-get install -y -qq mosquitto mosquitto-clients python3-pip curl unzip avahi-daemon qrencode

    # Python-Pakete
    apt-get install -y -qq python3-pynput python3-paho-mqtt python3-flask python3-qrcode 2>/dev/null || true
    pip3 install rpi_ws281x --break-system-packages 2>/dev/null || pip3 install rpi_ws281x 2>/dev/null || true
    pip3 install flask qrcode[pil] --break-system-packages 2>/dev/null || true

    print_success "Pakete installiert"

    # -------------------------------------------------------------------------
    # 3. Mosquitto konfigurieren
    # -------------------------------------------------------------------------
    print_step "4/9" "Konfiguriere MQTT-Broker..."

    # Backup
    [ -f /etc/mosquitto/mosquitto.conf ] && cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.backup

    # SIDEKICK-Konfiguration
    cat > /etc/mosquitto/conf.d/sidekick.conf << EOF
# SIDEKICK MQTT Konfiguration
allow_anonymous true
listener 1883
listener 9001
protocol websockets
EOF

    systemctl enable mosquitto
    systemctl restart mosquitto

    print_success "Mosquitto konfiguriert (Port 1883 + WebSocket 9001)"

    # -------------------------------------------------------------------------
    # 4. Hostname einrichten
    # -------------------------------------------------------------------------
    print_step "5/9" "Richte Hostname ein..."

    # Prüfe ob bereits ein SIDEKICK-Hostname existiert
    CURRENT_HOSTNAME=$(hostname)
    if [[ "$CURRENT_HOSTNAME" == sidekick-* ]]; then
        SIDEKICK_HOSTNAME="$CURRENT_HOSTNAME"
        print_info "Behalte bestehenden Hostname: $SIDEKICK_HOSTNAME"
    else
        SIDEKICK_HOSTNAME=$(generate_hostname)
        
        # Hostname setzen
        hostnamectl set-hostname "$SIDEKICK_HOSTNAME"
        
        # /etc/hosts aktualisieren
        sed -i "s/127.0.1.1.*/127.0.1.1\t$SIDEKICK_HOSTNAME/g" /etc/hosts
        if ! grep -q "$SIDEKICK_HOSTNAME" /etc/hosts; then
            echo "127.0.1.1	$SIDEKICK_HOSTNAME" >> /etc/hosts
        fi
        
        print_success "Hostname gesetzt: $SIDEKICK_HOSTNAME"
    fi

    # Avahi für .local Auflösung
    systemctl enable avahi-daemon
    systemctl restart avahi-daemon

    print_success "mDNS aktiviert: ${SIDEKICK_HOSTNAME}.local"

    # -------------------------------------------------------------------------
    # 5. WLAN-Hotspot einrichten
    # -------------------------------------------------------------------------
    print_step "6/9" "Richte WLAN-Hotspot ein..."

    HOTSPOT_SSID="SIDEKICK-${SIDEKICK_HOSTNAME#sidekick-}"
    HOTSPOT_SSID=$(echo "$HOTSPOT_SSID" | tr '[:lower:]' '[:upper:]')
    HOTSPOT_PASSWORD="sidekick"

    if ! nmcli device status | grep -q "wifi"; then
        print_info "Kein WLAN-Interface gefunden. Hotspot übersprungen."
    else
        # Bestehenden Hotspot löschen
        nmcli connection delete Hotspot 2>/dev/null || true
        
        # Neuen Hotspot erstellen
        nmcli device wifi hotspot ssid "$HOTSPOT_SSID" password "$HOTSPOT_PASSWORD"
        nmcli connection modify Hotspot autoconnect yes
        nmcli connection modify Hotspot connection.autoconnect-priority 100
        
        print_success "Hotspot: $HOTSPOT_SSID (Passwort: $HOTSPOT_PASSWORD)"
    fi

else
    # UPDATE-Modus: Nur Schritte überspringen
    print_step "3/9" "Pakete... (übersprungen - bereits installiert)"
    print_step "4/9" "MQTT... (übersprungen - bereits konfiguriert)"
    print_step "5/9" "Hostname... (übersprungen - bereits gesetzt)"
    print_step "6/9" "Hotspot... (übersprungen - bereits konfiguriert)"
    
    # Hostname für später ermitteln
    SIDEKICK_HOSTNAME=$(hostname)
    HOTSPOT_SSID="SIDEKICK-${SIDEKICK_HOSTNAME#sidekick-}"
    HOTSPOT_SSID=$(echo "$HOTSPOT_SSID" | tr '[:lower:]' '[:upper:]')
    HOTSPOT_PASSWORD="sidekick"
fi

# =============================================================================
# IMMER: Download und Installation
# =============================================================================

# -----------------------------------------------------------------------------
# 6. Verzeichnisse und Backup
# -----------------------------------------------------------------------------
print_step "7/9" "Bereite Installation vor..."

mkdir -p "$SIDEKICK_DIR"

# Backup von Benutzer-Dateien (Projekte, Videos)
BACKUP_DIR="$SIDEKICK_DIR/.backup_temp"
if [ -d "$WEBAPP_DIR/projects" ] || [ -d "$WEBAPP_DIR/videos" ]; then
    print_info "Sichere Projekte und Videos..."
    mkdir -p "$BACKUP_DIR"
    [ -d "$WEBAPP_DIR/projects" ] && cp -r "$WEBAPP_DIR/projects" "$BACKUP_DIR/"
    [ -d "$WEBAPP_DIR/videos" ] && cp -r "$WEBAPP_DIR/videos" "$BACKUP_DIR/"
fi

print_success "Vorbereitung abgeschlossen"

# -----------------------------------------------------------------------------
# 7. Download und Installation
# -----------------------------------------------------------------------------
print_step "8/9" "Lade SIDEKICK $LATEST_VERSION herunter..."

cd "$SIDEKICK_DIR"

# Download
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_VERSION/sidekick-$LATEST_VERSION.zip"
TEMP_ZIP="$SIDEKICK_DIR/sidekick-update.zip"
TEMP_DIR="$SIDEKICK_DIR/sidekick-update-temp"

if ! curl -sSL "$DOWNLOAD_URL" -o "$TEMP_ZIP" 2>/dev/null; then
    print_error "Download fehlgeschlagen!"
    echo "      URL: $DOWNLOAD_URL"
    exit 1
fi

print_success "Download abgeschlossen"

# Alte Dateien entfernen
rm -rf "$WEBAPP_DIR"
rm -rf "$PYTHON_DIR"
rm -rf "$SCRIPTS_DIR"

# Entpacken
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"
rm -f "$TEMP_ZIP"

# Neue Dateien installieren
mv "$TEMP_DIR/sidekick" "$WEBAPP_DIR" 2>/dev/null || true
mv "$TEMP_DIR/python" "$PYTHON_DIR" 2>/dev/null || true
mv "$TEMP_DIR/scripts" "$SCRIPTS_DIR" 2>/dev/null || true

# VERSION speichern
cp "$TEMP_DIR/VERSION" "$SIDEKICK_DIR/VERSION" 2>/dev/null || echo "$LATEST_VERSION" > "$SIDEKICK_DIR/VERSION"

# Hostname-Datei für Dashboard speichern
echo "$SIDEKICK_HOSTNAME" > "$SIDEKICK_DIR/HOSTNAME"

# Setup-Script aktualisieren
if [ -f "$SCRIPTS_DIR/sidekick-setup.sh" ]; then
    cp "$SCRIPTS_DIR/sidekick-setup.sh" "$SIDEKICK_DIR/sidekick-setup.sh"
fi

# Aufräumen
rm -rf "$TEMP_DIR"

# Benutzer-Dateien wiederherstellen
if [ -d "$BACKUP_DIR" ]; then
    print_info "Stelle Projekte und Videos wieder her..."
    [ -d "$BACKUP_DIR/projects" ] && cp -r "$BACKUP_DIR/projects" "$WEBAPP_DIR/"
    [ -d "$BACKUP_DIR/videos" ] && cp -r "$BACKUP_DIR/videos" "$WEBAPP_DIR/"
    rm -rf "$BACKUP_DIR"
fi

# Ordner sicherstellen
mkdir -p "$WEBAPP_DIR/projects"
mkdir -p "$WEBAPP_DIR/videos"

# Rechte setzen
chmod +x "$SIDEKICK_DIR"/*.sh 2>/dev/null || true
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$SIDEKICK_DIR"

print_success "Installation abgeschlossen"

# -----------------------------------------------------------------------------
# 8. Services einrichten / neustarten
# -----------------------------------------------------------------------------
print_step "9/9" "Konfiguriere Services..."

# Service-Pfade
PYTHON_SCRIPT="$PYTHON_DIR/ScratchConnect.py"
DASHBOARD_SCRIPT="$PYTHON_DIR/sidekick-dashboard.py"

if [ "$IS_UPDATE" = false ]; then
    # ERSTINSTALLATION: Services erstellen

    # HTTP-Server Service
    cat > /etc/systemd/system/sidekick-webapp.service << EOF
[Unit]
Description=SIDEKICK Scratch Webapp HTTP Server
After=network.target mosquitto.service
Wants=mosquitto.service

[Service]
Type=simple
User=$ACTUAL_USER
WorkingDirectory=$WEBAPP_DIR
ExecStart=/usr/bin/python3 -m http.server 8601 --bind 0.0.0.0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Sensor Service
    cat > /etc/systemd/system/sidekick-sensors.service << EOF
[Unit]
Description=SIDEKICK ScratchConnect Sensor Service
After=network.target mosquitto.service sidekick-webapp.service
Wants=mosquitto.service

[Service]
Type=simple
User=root
WorkingDirectory=$PYTHON_DIR
ExecStart=/usr/bin/python3 $PYTHON_SCRIPT
Restart=always
RestartSec=5
ExecStartPre=/bin/sleep 3

[Install]
WantedBy=multi-user.target
EOF

    # Dashboard Service
    cat > /etc/systemd/system/sidekick-dashboard.service << EOF
[Unit]
Description=SIDEKICK Dashboard Web Interface
After=network.target sidekick-webapp.service
Wants=sidekick-webapp.service

[Service]
Type=simple
User=$ACTUAL_USER
WorkingDirectory=$PYTHON_DIR
ExecStart=/usr/bin/python3 $DASHBOARD_SCRIPT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sidekick-webapp.service
    systemctl enable sidekick-sensors.service
    systemctl enable sidekick-dashboard.service
    systemctl start sidekick-webapp.service
    systemctl start sidekick-sensors.service
    systemctl start sidekick-dashboard.service

    print_success "Services erstellt und gestartet"

else
    # UPDATE: Services nur neustarten (falls aktiv)
    systemctl daemon-reload
    
    if systemctl is-enabled --quiet sidekick-webapp 2>/dev/null; then
        systemctl restart sidekick-webapp
        print_success "sidekick-webapp neu gestartet"
    fi

    if systemctl is-enabled --quiet sidekick-sensors 2>/dev/null; then
        systemctl restart sidekick-sensors
        print_success "sidekick-sensors neu gestartet"
    fi

    if systemctl is-enabled --quiet sidekick-dashboard 2>/dev/null; then
        systemctl restart sidekick-dashboard
        print_success "sidekick-dashboard neu gestartet"
    fi
fi

# =============================================================================
# NUR BEI ERSTINSTALLATION: Optionale Extras
# =============================================================================
if [ "$IS_UPDATE" = false ]; then

    # -------------------------------------------------------------------------
    # Desktop-Shortcuts
    # -------------------------------------------------------------------------
    DESKTOP_DIR="$USER_HOME/Desktop"
    mkdir -p "$DESKTOP_DIR"

    cat > "$DESKTOP_DIR/sidekick-update.desktop" << EOF
[Desktop Entry]
Name=SIDEKICK Update
Comment=Aktualisiert SIDEKICK
Exec=lxterminal -e "bash -c 'sudo $SIDEKICK_DIR/sidekick-setup.sh; echo; read -p \"Enter drücken...\"'"
Icon=system-software-update
Terminal=false
Type=Application
EOF

    cat > "$DESKTOP_DIR/sidekick-status.desktop" << EOF
[Desktop Entry]
Name=SIDEKICK Status
Comment=Zeigt Status der SIDEKICK-Dienste
Exec=lxterminal -e "bash -c 'echo === SIDEKICK Status ===; echo; echo Hostname: \$(hostname); echo Version: \$(cat $SIDEKICK_DIR/VERSION 2>/dev/null || echo unbekannt); echo; systemctl status sidekick-webapp sidekick-sensors sidekick-dashboard --no-pager; echo; read -p \"Enter drücken...\"'"
Icon=dialog-information
Terminal=false
Type=Application
EOF

    chmod +x "$DESKTOP_DIR"/sidekick-*.desktop 2>/dev/null || true
    chown "$ACTUAL_USER:$ACTUAL_USER" "$DESKTOP_DIR"/sidekick-*.desktop 2>/dev/null || true

    # Trust setzen
    if command -v gio &> /dev/null; then
        sudo -u "$ACTUAL_USER" gio set "$DESKTOP_DIR/sidekick-update.desktop" metadata::trusted true 2>/dev/null || true
        sudo -u "$ACTUAL_USER" gio set "$DESKTOP_DIR/sidekick-status.desktop" metadata::trusted true 2>/dev/null || true
    fi

    print_success "Desktop-Shortcuts installiert"

    # -------------------------------------------------------------------------
    # Kiosk-Modus Abfrage
    # -------------------------------------------------------------------------
    echo ""
    read -p "Kiosk-Modus einrichten (Fullscreen-Browser beim Start)? (j/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        
        cat > /etc/systemd/system/sidekick-kiosk.service << EOF
[Unit]
Description=SIDEKICK Kiosk Browser
After=graphical.target sidekick-webapp.service
Wants=sidekick-webapp.service

[Service]
Type=simple
User=$ACTUAL_USER
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run --disable-session-crashed-bubble --disable-component-update --password-store=basic --disable-translate http://localhost:8601/kiosk.html
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

        systemctl daemon-reload
        systemctl enable sidekick-kiosk.service
        
        print_success "Kiosk-Modus eingerichtet"
    else
        print_info "Kiosk-Modus übersprungen"
    fi
fi

# =============================================================================
# FERTIG - Zusammenfassung
# =============================================================================
echo ""
print_header "Setup abgeschlossen!"

echo -e "${GREEN}SIDEKICK $LATEST_VERSION ist einsatzbereit!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}Gerätename:${NC} $SIDEKICK_HOSTNAME"
echo ""
echo -e "${CYAN}Zugriff im Netzwerk:${NC}"
echo "  Scratch:    http://${SIDEKICK_HOSTNAME}.local:8601"
echo "  Dashboard:  http://${SIDEKICK_HOSTNAME}.local:5000"
echo ""
echo -e "${CYAN}Zugriff via Hotspot:${NC}"
echo "  WLAN:       $HOTSPOT_SSID"
echo "  Passwort:   $HOTSPOT_PASSWORD"
echo "  Scratch:    http://10.42.0.1:8601"
echo "  Dashboard:  http://10.42.0.1:5000"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# QR-Code generieren (falls qrencode installiert)
if command -v qrencode &> /dev/null; then
    echo ""
    echo -e "${CYAN}QR-Code für Scratch:${NC}"
    qrencode -t ANSIUTF8 "http://${SIDEKICK_HOSTNAME}.local:8601" 2>/dev/null || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Bei Erstinstallation: Reboot-Abfrage
if [ "$IS_UPDATE" = false ]; then
    read -p "Raspberry Pi jetzt neu starten? (J/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Starte neu..."
        sleep 2
        reboot
    else
        echo -e "${YELLOW}Bitte später manuell neu starten: sudo reboot${NC}"
    fi
else
    echo -e "${GREEN}Update abgeschlossen!${NC}"
fi
