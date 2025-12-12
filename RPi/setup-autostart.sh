#!/bin/bash
# =============================================================================
# SIDEKICK Autostart Setup Script
# =============================================================================
# Dieses Skript richtet den automatischen Start der SIDEKICK-Dienste ein:
# 1. HTTP-Server fuer die Scratch-Webapp
# 2. ScratchConnect.py fuer Sensor-Kommunikation
#
# Verwendung: sudo bash setup-autostart.sh
# =============================================================================

set -e

echo "=============================================="
echo "  SIDEKICK Autostart Setup"
echo "=============================================="
echo ""

# Pruefen ob als root ausgefuehrt
if [ "$EUID" -ne 0 ]; then
    echo "Bitte als root ausfuehren: sudo bash setup-autostart.sh"
    exit 1
fi

# Benutzer ermitteln (der sudo aufgerufen hat)
ACTUAL_USER="${SUDO_USER:-pi}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

echo "Benutzer: $ACTUAL_USER"
echo "Home-Verzeichnis: $USER_HOME"
echo ""

# -----------------------------------------------------------------------------
# Pfade definieren
# -----------------------------------------------------------------------------
SIDEKICK_DIR="$USER_HOME/Sidekick"
WEBAPP_DIR="$SIDEKICK_DIR/sidekick"
VIDEOS_DIR="$WEBAPP_DIR/videos"
PROJECTS_DIR="$WEBAPP_DIR/projects"
PYTHON_SCRIPT="$SIDEKICK_DIR/python/ScratchConnect.py"

# -----------------------------------------------------------------------------
# 0. Setup-Scripts und Ordner erstellen
# -----------------------------------------------------------------------------
echo "[0/5] Erstelle Ordner und kopiere Scripts..."

mkdir -p "$SIDEKICK_DIR"
mkdir -p "$VIDEOS_DIR"
mkdir -p "$PROJECTS_DIR"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$VIDEOS_DIR"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$PROJECTS_DIR"

# Setup-Scripts herunterladen (falls sie noch nicht da sind)
SCRIPTS_URL="https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi"
curl -sSL "$SCRIPTS_URL/update-sidekick.sh" -o "$SIDEKICK_DIR/update-sidekick.sh"
curl -sSL "$SCRIPTS_URL/setup-kiosk.sh" -o "$SIDEKICK_DIR/setup-kiosk.sh"
chmod +x "$SIDEKICK_DIR"/*.sh
chown "$ACTUAL_USER:$ACTUAL_USER" "$SIDEKICK_DIR"/*.sh

# Erstelle leere video-list.json falls nicht vorhanden
if [ ! -f "$VIDEOS_DIR/video-list.json" ]; then
    echo "[]" > "$VIDEOS_DIR/video-list.json"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$VIDEOS_DIR/video-list.json"
fi

# Erstelle leere project-list.json falls nicht vorhanden
if [ ! -f "$PROJECTS_DIR/project-list.json" ]; then
    echo "[]" > "$PROJECTS_DIR/project-list.json"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$PROJECTS_DIR/project-list.json"
fi

echo "   Abgeschlossen: Ordner und Scripts bereit"
    echo "[]" > "$VIDEOS_DIR/video-list.json"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$VIDEOS_DIR/video-list.json"
fi

echo "   Abgeschlossen: Ordner und Scripts bereit"

# -----------------------------------------------------------------------------
# 1. Systemd Service: SIDEKICK HTTP Server
# -----------------------------------------------------------------------------
echo "[1/5] Erstelle sidekick-webapp.service..."

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

echo "   Abgeschlossen: sidekick-webapp.service erstellt"

# -----------------------------------------------------------------------------
# 2. Systemd Service: SIDEKICK ScratchConnect (Sensoren)
# -----------------------------------------------------------------------------
echo "[2/5] Erstelle sidekick-sensors.service..."

cat > /etc/systemd/system/sidekick-sensors.service << EOF
[Unit]
Description=SIDEKICK ScratchConnect Sensor Service
After=network.target mosquitto.service
Wants=mosquitto.service

[Service]
Type=simple
User=root
WorkingDirectory=$SIDEKICK_DIR/python
ExecStart=/usr/bin/python3 $PYTHON_SCRIPT
Restart=always
RestartSec=5
# Warte kurz, damit MQTT-Broker bereit ist
ExecStartPre=/bin/sleep 3

[Install]
WantedBy=multi-user.target
EOF

echo "   Abgeschlossen: sidekick-sensors.service erstellt"

# -----------------------------------------------------------------------------
# 3. Systemd Service: SIDEKICK Dashboard (Upload & Verwaltung)
# -----------------------------------------------------------------------------
echo "[3/5] Erstelle sidekick-dashboard.service..."

DASHBOARD_SCRIPT="$SIDEKICK_DIR/python/sidekick-dashboard.py"

cat > /etc/systemd/system/sidekick-dashboard.service << EOF
[Unit]
Description=SIDEKICK Dashboard (Video/Projekt Upload)
After=network.target sidekick-webapp.service
Wants=sidekick-webapp.service

[Service]
Type=simple
User=$ACTUAL_USER
WorkingDirectory=$SIDEKICK_DIR/python
ExecStart=/usr/bin/python3 $DASHBOARD_SCRIPT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "   Abgeschlossen: sidekick-dashboard.service erstellt"

# -----------------------------------------------------------------------------
# 4. Services aktivieren
# -----------------------------------------------------------------------------
echo "[4/5] Aktiviere Services..."

systemctl daemon-reload
systemctl enable sidekick-webapp.service
systemctl enable sidekick-sensors.service
systemctl enable sidekick-dashboard.service

echo "   Abgeschlossen: Services aktiviert"

# -----------------------------------------------------------------------------
# 5. Services starten (optional)
# -----------------------------------------------------------------------------
echo "[5/5] Starte Services..."

systemctl start sidekick-webapp.service
systemctl start sidekick-sensors.service
systemctl start sidekick-dashboard.service

echo "   Abgeschlossen: Services gestartet"

# -----------------------------------------------------------------------------
# Zusammenfassung
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Setup abgeschlossen!"
echo "=============================================="
echo ""
echo "Die folgenden Services wurden eingerichtet:"
echo ""
echo "  - sidekick-webapp.service"
echo "    - HTTP-Server auf Port 8000"
echo "    - Webapp: $WEBAPP_DIR"
echo ""
echo "  - sidekick-sensors.service"
echo "    - ScratchConnect.py (Sensoren + LEDs)"
echo "    - Script: $PYTHON_SCRIPT"
echo ""
echo "  - sidekick-dashboard.service"
echo "    - Dashboard auf Port 8080"
echo "    - Video/Projekt Upload & Verwaltung"
echo ""
echo "Nuetzliche Befehle:"
echo ""
echo "  Status pruefen:"
echo "    sudo systemctl status sidekick-webapp"
echo "    sudo systemctl status sidekick-sensors"
echo "    sudo systemctl status sidekick-dashboard"
echo ""
echo "  Logs ansehen:"
echo "    sudo journalctl -u sidekick-webapp -f"
echo "    sudo journalctl -u sidekick-sensors -f"
echo "    sudo journalctl -u sidekick-dashboard -f"
echo ""
echo "  Neu starten:"
echo "    sudo systemctl restart sidekick-webapp"
echo "    sudo systemctl restart sidekick-sensors"
echo "    sudo systemctl restart sidekick-dashboard"
echo ""
echo "  Deaktivieren:"
echo "    sudo systemctl disable sidekick-webapp"
echo "    sudo systemctl disable sidekick-sensors"
echo "    sudo systemctl disable sidekick-dashboard"
echo ""
echo "URLs (im Hotspot-Modus):"
echo "  Scratch Editor: http://10.42.0.1:8000/"
echo "  Dashboard:      http://10.42.0.1:8080/"
echo ""
echo "Nach einem Neustart starten alle Dienste automatisch!"
echo ""
