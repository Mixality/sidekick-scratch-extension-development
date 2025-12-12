#!/bin/bash
# =============================================================================
# SIDEKICK Komplett-Installation
# =============================================================================
# Dieses Skript richtet einen frischen Raspberry Pi komplett fuer SIDEKICK ein:
# - Mosquitto MQTT-Broker (mit WebSocket-Support)
# - WLAN-Hotspot (damit Tablets sich verbinden koennen)
# - SIDEKICK-Dateien herunterladen
# - Autostart-Services einrichten
#
# Verwendung: sudo bash install-sidekick.sh
# =============================================================================

set -e

# Farben fuer Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "=============================================="
echo "  SIDEKICK Komplett-Installation"
echo "=============================================="
echo ""

# -----------------------------------------------------------------------------
# Voraussetzungen pruefen
# -----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Fehler: Bitte als root ausfuehren: sudo bash install-sidekick.sh${NC}"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-pi}"
USER_HOME=$(eval echo ~$ACTUAL_USER)
SIDEKICK_DIR="$USER_HOME/Sidekick"

echo "Benutzer: $ACTUAL_USER"
echo "Home-Verzeichnis: $USER_HOME"
echo "SIDEKICK-Verzeichnis: $SIDEKICK_DIR"
echo ""

# -----------------------------------------------------------------------------
# Seriennummer fuer eindeutigen Hotspot-Namen ermitteln
# -----------------------------------------------------------------------------
SERIAL=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2 | tail -c 17)
if [ -z "$SERIAL" ]; then
    SERIAL="unknown"
fi
HOTSPOT_SSID="SIDEKICK-RPi-$SERIAL"
HOTSPOT_PASSWORD="sidekick"

echo "Hotspot wird eingerichtet als: $HOTSPOT_SSID"
echo ""

# Bestaetigung
read -p "Fortfahren? (j/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Jj]$ ]]; then
    echo "Abgebrochen."
    exit 1
fi

echo ""

# -----------------------------------------------------------------------------
# 1. System-Updates und Pakete installieren
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/7] Installiere benoetigte Pakete...${NC}"

apt-get update -qq
apt-get install -y -qq mosquitto mosquitto-clients python3-pip curl unzip

# Python-Pakete (fuer Sensoren/LEDs)
apt-get install -y -qq python3-pynput python3-paho-mqtt || true
pip3 install rpi_ws281x --break-system-packages 2>/dev/null || pip3 install rpi_ws281x || true

echo -e "${GREEN}   Pakete installiert${NC}"

# -----------------------------------------------------------------------------
# 2. Mosquitto MQTT-Broker konfigurieren
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/7] Konfiguriere Mosquitto MQTT-Broker...${NC}"

# Backup der Original-Konfiguration
if [ -f /etc/mosquitto/mosquitto.conf ]; then
    cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.backup
fi

# SIDEKICK-spezifische Konfiguration
cat > /etc/mosquitto/conf.d/sidekick.conf << EOF
# SIDEKICK MQTT Konfiguration
# Anonyme Verbindungen erlauben (fuer lokales Netzwerk)
allow_anonymous true

# Standard MQTT Port
listener 1883

# WebSocket Listener (fuer Browser/Scratch)
listener 9001
protocol websockets
EOF

# Mosquitto aktivieren und starten
systemctl enable mosquitto
systemctl restart mosquitto

echo -e "${GREEN}   Mosquitto konfiguriert (Port 1883 + WebSocket 9001)${NC}"

# -----------------------------------------------------------------------------
# 3. WLAN-Hotspot einrichten
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/7] Richte WLAN-Hotspot ein...${NC}"

# Pruefen ob WLAN-Interface existiert
if ! nmcli device status | grep -q "wifi"; then
    echo -e "${RED}   Warnung: Kein WLAN-Interface gefunden. Hotspot wird uebersprungen.${NC}"
else
    # Bestehenden Hotspot loeschen falls vorhanden
    nmcli connection delete Hotspot 2>/dev/null || true
    
    # Neuen Hotspot erstellen
    nmcli device wifi hotspot ssid "$HOTSPOT_SSID" password "$HOTSPOT_PASSWORD"
    
    # Autoconnect aktivieren mit hoher Prioritaet
    nmcli connection modify Hotspot autoconnect yes
    nmcli connection modify Hotspot connection.autoconnect-priority 100
    
    echo -e "${GREEN}   Hotspot eingerichtet:${NC}"
    echo "      SSID: $HOTSPOT_SSID"
    echo "      Passwort: $HOTSPOT_PASSWORD"
fi

# -----------------------------------------------------------------------------
# 4. SIDEKICK-Verzeichnis erstellen
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/7] Erstelle SIDEKICK-Verzeichnis...${NC}"

mkdir -p "$SIDEKICK_DIR"
mkdir -p "$SIDEKICK_DIR/python"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$SIDEKICK_DIR"

echo -e "${GREEN}   Verzeichnis erstellt: $SIDEKICK_DIR${NC}"

# -----------------------------------------------------------------------------
# 5. SIDEKICK-Dateien herunterladen (von GitHub Releases)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[5/7] Lade SIDEKICK-Dateien herunter...${NC}"

GITHUB_REPO="Mixality/sidekick-scratch-extension-development"

# Neuestes Release ermitteln
echo "   Ermittle neueste Version..."
LATEST_VERSION=$(curl -sSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}   FEHLER: Konnte neueste Version nicht ermitteln!${NC}"
    exit 1
fi
echo -e "${GREEN}   Neueste Version: $LATEST_VERSION${NC}"

# Release herunterladen
cd "$SIDEKICK_DIR"
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_VERSION/sidekick-$LATEST_VERSION.zip"
echo "   Lade herunter..."
curl -sSL "$DOWNLOAD_URL" -o sidekick-release.zip
unzip -q sidekick-release.zip
rm -f sidekick-release.zip

# VERSION-Datei speichern
echo "$LATEST_VERSION" > "$SIDEKICK_DIR/VERSION"

# Update-Script ins Hauptverzeichnis kopieren
if [ -f "$SIDEKICK_DIR/scripts/update-sidekick.sh" ]; then
    cp "$SIDEKICK_DIR/scripts/update-sidekick.sh" "$SIDEKICK_DIR/update-sidekick.sh"
fi

chmod +x "$SIDEKICK_DIR"/*.sh 2>/dev/null || true
chmod +x "$SIDEKICK_DIR/scripts"/*.sh 2>/dev/null || true
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$SIDEKICK_DIR"

echo -e "${GREEN}   Dateien heruntergeladen${NC}"

# -----------------------------------------------------------------------------
# 6. Autostart-Services einrichten
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[6/7] Richte Autostart-Services ein...${NC}"

WEBAPP_DIR="$SIDEKICK_DIR/sidekick"
PYTHON_SCRIPT="$SIDEKICK_DIR/python/ScratchConnect.py"

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
ExecStart=/usr/bin/python3 -m http.server 8000 --bind 0.0.0.0
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
WorkingDirectory=$SIDEKICK_DIR/python
ExecStart=/usr/bin/python3 $PYTHON_SCRIPT
Restart=always
RestartSec=5
ExecStartPre=/bin/sleep 3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sidekick-webapp.service
systemctl enable sidekick-sensors.service
systemctl start sidekick-webapp.service
systemctl start sidekick-sensors.service

echo -e "${GREEN}   Autostart-Services eingerichtet${NC}"

# -----------------------------------------------------------------------------
# 7. Desktop-Shortcuts installieren (optional)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[7/7] Installiere Desktop-Shortcuts...${NC}"

DESKTOP_DIR="$USER_HOME/Desktop"
mkdir -p "$DESKTOP_DIR"

# Update Shortcut
cat > "$DESKTOP_DIR/sidekick-update.desktop" << EOF
[Desktop Entry]
Name=SIDEKICK Update
Comment=Aktualisiert SIDEKICK vom GitHub Repository
Exec=lxterminal -e "bash -c '$SIDEKICK_DIR/update-sidekick.sh; echo; echo Druecke Enter zum Schliessen...; read'"
Icon=system-software-update
Terminal=false
Type=Application
EOF

# Restart Shortcut
cat > "$DESKTOP_DIR/sidekick-restart.desktop" << EOF
[Desktop Entry]
Name=SIDEKICK Neustart
Comment=Startet SIDEKICK-Dienste neu
Exec=lxterminal -e "bash -c 'sudo systemctl restart sidekick-webapp sidekick-sensors; echo Dienste neu gestartet!; echo Druecke Enter...; read'"
Icon=view-refresh
Terminal=false
Type=Application
EOF

# Status Shortcut
cat > "$DESKTOP_DIR/sidekick-status.desktop" << EOF
[Desktop Entry]
Name=SIDEKICK Status
Comment=Zeigt Status der SIDEKICK-Dienste
Exec=lxterminal -e "bash -c 'echo === SIDEKICK Status ===; systemctl status sidekick-webapp --no-pager; systemctl status sidekick-sensors --no-pager; echo; read'"
Icon=dialog-information
Terminal=false
Type=Application
EOF

chmod +x "$DESKTOP_DIR"/sidekick-*.desktop
chown "$ACTUAL_USER:$ACTUAL_USER" "$DESKTOP_DIR"/sidekick-*.desktop

# Trust setzen (neuere RPi OS Versionen)
if command -v gio &> /dev/null; then
    sudo -u "$ACTUAL_USER" gio set "$DESKTOP_DIR/sidekick-update.desktop" metadata::trusted true 2>/dev/null || true
    sudo -u "$ACTUAL_USER" gio set "$DESKTOP_DIR/sidekick-restart.desktop" metadata::trusted true 2>/dev/null || true
    sudo -u "$ACTUAL_USER" gio set "$DESKTOP_DIR/sidekick-status.desktop" metadata::trusted true 2>/dev/null || true
fi

echo -e "${GREEN}   Desktop-Shortcuts installiert${NC}"

# -----------------------------------------------------------------------------
# Fertig!
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo -e "${GREEN}  Installation abgeschlossen!${NC}"
echo "=============================================="
echo ""
echo "SIDEKICK ist jetzt einsatzbereit!"
echo ""
echo "Hotspot:"
echo "  SSID:     $HOTSPOT_SSID"
echo "  Passwort: $HOTSPOT_PASSWORD"
echo ""
echo "Verbindung (vom Tablet/Laptop):"
echo "  1. Mit WLAN '$HOTSPOT_SSID' verbinden"
echo "  2. Browser: http://10.42.0.1:8000"
echo "  3. In Scratch: Verbinde mit ws://10.42.0.1:9001"
echo ""
echo "Dienste:"
echo "  - sidekick-webapp  (HTTP-Server)"
echo "  - sidekick-sensors (ScratchConnect)"
echo "  - mosquitto        (MQTT-Broker)"
echo ""
echo "Desktop-Shortcuts wurden installiert fuer:"
echo "  - Update"
echo "  - Neustart"
echo "  - Status"
echo ""
echo -e "${YELLOW}Empfehlung: Raspberry Pi jetzt neu starten!${NC}"
echo "  sudo reboot"
echo ""
