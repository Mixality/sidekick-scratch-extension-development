#!/bin/bash
# =============================================================================
# SIDEKICK Setup Script (Unified Install & Update)
# =============================================================================
# Dieses Script erkennt automatisch ob SIDEKICK bereits installiert ist:
#   - Falls NEIN: Vollständige Installation
#   - Falls JA:   Update auf neueste Version
#
# Verwendung:
#   sudo bash sidekick-setup.sh              --> Stabiles Release
#   sudo bash sidekick-setup.sh --pre        --> Inklusive Pre-Releases
#   sudo bash sidekick-setup.sh --force      --> Erzwingt Neuinstallation
#   sudo bash sidekick-setup.sh --help       --> Zeigt Hilfe
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
        --kiosk)
            ENABLE_KIOSK=true
            ;;
        --hostname=*)
            CUSTOM_HOSTNAME="${arg#*=}"
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
    echo "  --kiosk                 Aktiviert automatisch den Kiosk-Modus"
    echo "  --hostname=NAME         Setzt eigenen Hostnamen (z.B. --hostname=schule1)"
    echo "  --help, -h              Zeigt diese Hilfe"
    echo ""
    echo "Beispiele:"
    echo "  sudo bash sidekick-setup.sh              Neuestes stabiles Release"
    echo "  sudo bash sidekick-setup.sh --pre        Neuestes Release (inkl. Test)"
    echo "  sudo bash sidekick-setup.sh --force      Erzwingt komplette Neuinstallation"
    echo "  sudo bash sidekick-setup.sh --kiosk      Mit Kiosk-Modus (Vollbild-Browser)"
    echo "  sudo bash sidekick-setup.sh --hostname=schule1 --kiosk"
    echo "                                           Mit eigenem Namen 'sidekick-schule1'"
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

print_warning() {
    echo -e "${YELLOW}   ⚠ $1${NC}"
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
    # Generiert einen eindeutigen Hostnamen basierend auf Pi-Seriennummer
    # Format: sidekick-XXXXXX (letzte 6 Zeichen der Seriennummer, lowercase)
    # Die Seriennummer ist auf dem Pi-Aufkleber ablesbar!
    local serial=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2 | tail -c 7 | tr '[:upper:]' '[:lower:]')
    if [ -z "$serial" ]; then
        # Fallback: MAC-Adresse Hash
        serial=$(cat /sys/class/net/*/address 2>/dev/null | head -1 | md5sum | cut -c1-6)
    fi
    if [ -z "$serial" ]; then
        # Fallback: Random
        serial=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 6)
    fi
    echo "sidekick-$serial"
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
print_header "SIDEKICK Setup: $MODE_TEXT"

echo "Benutzer:                     $ACTUAL_USER"
echo "Benutzer-Home:                $USER_HOME"
echo "SIDEKICK-Verzeichnis-Pfad:    $SIDEKICK_DIR"
if [ -n "$CURRENT_VERSION" ]; then
    echo "Aktuell installiert:      $CURRENT_VERSION"
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
    print_error "Neueste Version konnte nicht ermittelt werden!"
    echo "      Bitte Internetverbindung prüfen."
    exit 1
fi

print_success "Neueste Version: $LATEST_VERSION"

# Bei Update: Prüfen ob nötig
if [ "$IS_UPDATE" = true ] && [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && [ "$FORCE_INSTALL" = false ]; then
    echo ""
    echo -e "${GREEN}   Die neueste Version ist bereits installiert!${NC}"
    echo ""
    read -p "   Dennoch neu installieren? (j/N): " -n 1 -r
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
    read -p "Mit Installation fortfahren? (J/n): " -n 1 -r
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
    # Prüfe ob Service existiert (loaded)
    if systemctl list-unit-files "$service.service" &>/dev/null; then
        # Stoppe unabhängig vom Status (active, activating, failed, etc.)
        systemctl stop "$service" 2>/dev/null && print_info "Gestoppt: $service" || true
        systemctl disable "$service" 2>/dev/null || true
    fi
done

# Alte Ports freigeben (8000, 8080 - die alten Ports)
OLD_PORTS=(8000 8080)
for port in "${OLD_PORTS[@]}"; do
    # Finde Prozesse die auf alten Ports lauschen und beende sie
    OLD_PIDS=$(lsof -t -i:$port 2>/dev/null || ss -tlnp | grep ":$port " | grep -oP 'pid=\K\d+' || true)
    if [ -n "$OLD_PIDS" ]; then
        for pid in $OLD_PIDS; do
            if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
                kill $pid 2>/dev/null && print_info "Prozess auf Port $port beendet (PID: $pid)" || true
            fi
        done
    fi
done

# Auch neue Ports freigeben falls ein alter Prozess sie blockiert
NEW_PORTS=(8601 5000)
for port in "${NEW_PORTS[@]}"; do
    OLD_PIDS=$(lsof -t -i:$port 2>/dev/null || ss -tlnp | grep ":$port " | grep -oP 'pid=\K\d+' || true)
    if [ -n "$OLD_PIDS" ]; then
        for pid in $OLD_PIDS; do
            if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
                kill $pid 2>/dev/null && print_info "Prozess auf Port $port beendet (PID: $pid)" || true
            fi
        done
    fi
done

systemctl daemon-reload

print_success "Cleanup abgeschlossen"

# =============================================================================
# NUR BEI ERSTINSTALLATION: System-Setup
# =============================================================================
if [ "$IS_UPDATE" = false ]; then

    # -------------------------------------------------------------------------
    # 3. Pakete installieren
    # -------------------------------------------------------------------------
    print_step "3/9" "Installiere notwendige Pakete..."

    apt-get update -qq
    apt-get install -y -qq mosquitto mosquitto-clients python3-pip curl unzip avahi-daemon qrencode

    # Python-Pakete
    apt-get install -y -qq python3-pynput python3-paho-mqtt python3-flask python3-qrcode 2>/dev/null || true
    pip3 install rpi_ws281x --break-system-packages 2>/dev/null || pip3 install rpi_ws281x 2>/dev/null || true
    pip3 install flask qrcode[pil] --break-system-packages 2>/dev/null || true

    print_success "Pakete erfolgreich installiert"

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

    print_success "Mosquitto erfolgreich konfiguriert (Port: 1883 + WebSocket: 9001)"

    # -------------------------------------------------------------------------
    # 4. Hostname einrichten
    # -------------------------------------------------------------------------
    print_step "5/9" "Richte Hostname ein..."

    # Prüfe ob bereits ein SIDEKICK-Hostname existiert
    CURRENT_HOSTNAME=$(hostname)
    
    if [ -n "$CUSTOM_HOSTNAME" ]; then
        # Eigener Hostname per Parameter
        # Entferne 'sidekick-' Prefix falls der User es mitgegeben hat
        CUSTOM_HOSTNAME="${CUSTOM_HOSTNAME#sidekick-}"
        
        # Validierung: Nur erlaubte Zeichen (a-z, 0-9, -)
        CUSTOM_HOSTNAME=$(echo "$CUSTOM_HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
        
        # Max Länge prüfen (SSID max 32 Zeichen, "SIDEKICK-" = 9 Zeichen, also max 23 für Namen)
        if [ ${#CUSTOM_HOSTNAME} -gt 23 ]; then
            CUSTOM_HOSTNAME="${CUSTOM_HOSTNAME:0:23}"
            print_warning "Hostname auf 23 Zeichen gekürzt (SSID-Limit)"
        fi
        
        SIDEKICK_HOSTNAME="sidekick-${CUSTOM_HOSTNAME}"
        print_info "Verwende benutzerdefinierten Hostname: $SIDEKICK_HOSTNAME"
    elif [[ "$CURRENT_HOSTNAME" == sidekick-* ]]; then
        SIDEKICK_HOSTNAME="$CURRENT_HOSTNAME"
        print_info "Behalte bestehenden Hostname: $SIDEKICK_HOSTNAME"
    else
        SIDEKICK_HOSTNAME=$(generate_hostname)
    fi
    
    # Hostname setzen falls geändert
    if [ "$CURRENT_HOSTNAME" != "$SIDEKICK_HOSTNAME" ]; then
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

    # Hotspot-Name = Hostname (alles lowercase)
    HOTSPOT_SSID="$SIDEKICK_HOSTNAME"
    HOTSPOT_PASSWORD="sidekick"

    if ! nmcli device status | grep -q "wifi"; then
        print_info "Kein WLAN-Interface gefunden. Hotspot übersprungen."
    else
        # Bestehenden Hotspot löschen
        nmcli connection delete Hotspot 2>/dev/null || true
        
        # Neuen Hotspot erstellen (gleicher Name wie Hostname)
        HOTSPOT_SSID="$SIDEKICK_HOSTNAME"
        HOTSPOT_PASSWORD="sidekick"
        
        nmcli device wifi hotspot ssid "$HOTSPOT_SSID" password "$HOTSPOT_PASSWORD"
        nmcli connection modify Hotspot autoconnect yes
        nmcli connection modify Hotspot connection.autoconnect-priority 100
        
        print_success "Hotspot-Name: $HOTSPOT_SSID (Passwort: $HOTSPOT_PASSWORD)"
    fi

else
    # UPDATE-Modus: Nur Schritte überspringen
    print_step "3/9" "Pakete... (übersprungen: bereits installiert)"
    print_step "4/9" "MQTT... (übersprungen: bereits konfiguriert)"
    print_step "5/9" "Hostname... (übersprungen: bereits gesetzt)"
    print_step "6/9" "Hotspot... (übersprungen: bereits konfiguriert)"
    
    # Hostname für später ermitteln
    SIDEKICK_HOSTNAME=$(hostname)
    HOTSPOT_SSID="$SIDEKICK_HOSTNAME"
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
    print_info "Sichere Projekt- und Videodateien..."
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
    print_info "Stelle Projekt- und Videodateien wieder her..."
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

    # USB-Import udev-Rule (triggert bei USB-Einstecken)
    cat > /etc/udev/rules.d/99-sidekick-usb-import.rules << EOF
# SIDEKICK USB-Import: Startet Import wenn USB-Stick eingesteckt wird
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="/bin/bash $PYTHON_DIR/sidekick-usb-import.sh"
EOF

    # udev-Regeln neu laden
    udevadm control --reload-rules 2>/dev/null || true

    systemctl daemon-reload
    systemctl enable sidekick-webapp.service
    systemctl enable sidekick-sensors.service
    systemctl enable sidekick-dashboard.service
    systemctl start sidekick-webapp.service
    systemctl start sidekick-sensors.service
    systemctl start sidekick-dashboard.service

    print_success "Services erstellt und gestartet (inkl. USB-Import)"

else
    # UPDATE: Services aktivieren und starten
    # Prüft ob Service-Datei existiert (nicht is-enabled, da Service disabled sein könnte)
    systemctl daemon-reload
    
    if [ -f /etc/systemd/system/sidekick-webapp.service ]; then
        systemctl enable --now sidekick-webapp
        print_success "sidekick-webapp gestartet"
    fi

    if [ -f /etc/systemd/system/sidekick-sensors.service ]; then
        systemctl enable --now sidekick-sensors
        print_success "sidekick-sensors gestartet"
    fi

    if [ -f /etc/systemd/system/sidekick-dashboard.service ]; then
        systemctl enable --now sidekick-dashboard
        print_success "sidekick-dashboard gestartet"
    fi
    
    # USB-Import udev-Rule auch bei Update installieren/aktualisieren
    cat > /etc/udev/rules.d/99-sidekick-usb-import.rules << EOF
# SIDEKICK USB-Import: Startet Import wenn USB-Stick eingesteckt wird
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="/bin/bash $PYTHON_DIR/sidekick-usb-import.sh"
EOF
    udevadm control --reload-rules 2>/dev/null || true
    print_success "USB-Import aktualisiert"
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
    
    # Prüfe ob --kiosk Flag gesetzt oder interaktiv fragen
    SETUP_KIOSK=false
    if [ "$ENABLE_KIOSK" = true ]; then
        SETUP_KIOSK=true
        print_info "Kiosk-Modus wird eingerichtet (--kiosk Flag)"
    elif [ -t 0 ]; then
        # Nur interaktiv fragen wenn stdin ein Terminal ist
        read -p "Kiosk-Modus einrichten (Fullscreen-Browser beim Start)? (j/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Jj]$ ]]; then
            SETUP_KIOSK=true
        fi
    else
        print_info "Kiosk-Modus übersprungen (nicht-interaktiv, nutze --kiosk zum Aktivieren)"
    fi
    
    if [ "$SETUP_KIOSK" = true ]; then
        
        # Chromium-Pfad ermitteln (unterschiedlich je nach RPi OS Version)
        CHROMIUM_PATH=""
        if command -v chromium-browser &> /dev/null; then
            CHROMIUM_PATH="/usr/bin/chromium-browser"
        elif command -v chromium &> /dev/null; then
            CHROMIUM_PATH="/usr/bin/chromium"
        else
            print_error "Chromium nicht gefunden! Installiere mit: sudo apt install chromium"
            CHROMIUM_PATH="/usr/bin/chromium"  # Fallback
        fi
        
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
ExecStart=$CHROMIUM_PATH --kiosk --noerrdialogs --disable-infobars --no-first-run --disable-session-crashed-bubble --disable-component-update --password-store=basic --disable-translate http://localhost:8601/kiosk.html
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

        systemctl daemon-reload
        systemctl enable sidekick-kiosk.service
        
        print_success "Kiosk-Modus eingerichtet (Chromium: $CHROMIUM_PATH)"
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
echo -e "${CYAN}Gerätename / Hostname:${NC} $SIDEKICK_HOSTNAME"
echo ""
echo -e "${CYAN}Zugriff im Netzwerk:${NC}"
echo "  Scratch-Editor:     http://${SIDEKICK_HOSTNAME}.local:8601"
echo "  SIDEKICK-Dashboard: http://${SIDEKICK_HOSTNAME}.local:5000"
echo ""
echo -e "${CYAN}Zugriff via Hotspot:${NC}"
echo "  WLAN:               $HOTSPOT_SSID"
echo "  Passwort:           $HOTSPOT_PASSWORD"
echo "  Scratch-Editor:     http://10.42.0.1:8601"
echo "  SIDEKICK-Dashboard: http://10.42.0.1:5000"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# QR-Code generieren (falls qrencode installiert)
if command -v qrencode &> /dev/null; then
    echo ""
    echo -e "${CYAN}QR-Code für SIDEKICK-Dashboard:${NC}"
    qrencode -t ANSIUTF8 "http://${SIDEKICK_HOSTNAME}.local:5000" 2>/dev/null || true
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
