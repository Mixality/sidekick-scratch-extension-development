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
WEBAPP_DIR="$SIDEKICK_DIR/sidekick-scratch-extension-development-gh-pages/scratch"
PYTHON_SCRIPT="$SIDEKICK_DIR/python/ScratchConnect.py"

# -----------------------------------------------------------------------------
# 1. Systemd Service: SIDEKICK HTTP Server
# -----------------------------------------------------------------------------
echo "[1/4] Erstelle sidekick-webapp.service..."

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
echo "[2/4] Erstelle sidekick-sensors.service..."

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
# 3. Services aktivieren
# -----------------------------------------------------------------------------
echo "[3/4] Aktiviere Services..."

systemctl daemon-reload
systemctl enable sidekick-webapp.service
systemctl enable sidekick-sensors.service

echo "   Abgeschlossen: Services aktiviert"

# -----------------------------------------------------------------------------
# 4. Services starten (optional)
# -----------------------------------------------------------------------------
echo "[4/4] Starte Services..."

systemctl start sidekick-webapp.service
systemctl start sidekick-sensors.service

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
echo "Nuetzliche Befehle:"
echo ""
echo "  Status pruefen:"
echo "    sudo systemctl status sidekick-webapp"
echo "    sudo systemctl status sidekick-sensors"
echo ""
echo "  Logs ansehen:"
echo "    sudo journalctl -u sidekick-webapp -f"
echo "    sudo journalctl -u sidekick-sensors -f"
echo ""
echo "  Neu starten:"
echo "    sudo systemctl restart sidekick-webapp"
echo "    sudo systemctl restart sidekick-sensors"
echo ""
echo "  Deaktivieren:"
echo "    sudo systemctl disable sidekick-webapp"
echo "    sudo systemctl disable sidekick-sensors"
echo ""
echo "Nach einem Neustart starten alle Dienste automatisch!"
echo ""
