#!/bin/bash
# ============================================
# SIDEKICK Kiosk-Modus Setup
# ============================================
# Richtet den Raspberry Pi als Kiosk-Display ein:
# - Chromium startet automatisch im Vollbild
# - Zeigt die Kiosk-Seite (wartet auf MQTT-Befehle)
# - Mauszeiger wird ausgeblendet
# - Bildschirmschoner deaktiviert
#
# Verwendung:
#   chmod +x setup-kiosk.sh
#   ./setup-kiosk.sh
#
# Nach dem Neustart startet der Kiosk automatisch!
# ============================================

set -e

echo "========================================"
echo "  SIDEKICK Kiosk-Modus Setup"
echo "========================================"
echo ""

# Überprüfe ob wir auf einem Pi sind
if ! command -v raspi-config &> /dev/null; then
    echo "⚠️  Warnung: raspi-config nicht gefunden."
    echo "   Dieses Script ist für Raspberry Pi OS gedacht."
    read -p "Trotzdem fortfahren? (j/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        exit 1
    fi
fi

# Benötigte Pakete installieren
echo "📦 Installiere benötigte Pakete..."
sudo apt-get update
sudo apt-get install -y \
    chromium-browser \
    unclutter \
    xdotool \
    --no-install-recommends

echo "✓ Pakete installiert!"

# Kiosk-Script erstellen
echo ""
echo "📝 Erstelle Kiosk-Start-Script..."

KIOSK_SCRIPT="$HOME/start-kiosk.sh"
cat > "$KIOSK_SCRIPT" << 'KIOSK_EOF'
#!/bin/bash
# SIDEKICK Kiosk Start Script
# Startet Chromium im Kiosk-Modus

# Warte auf Display
sleep 5

# Bildschirmschoner und Energiesparmodus deaktivieren
xset s off
xset s noblank
xset -dpms

# Mauszeiger nach 0.5 Sekunden Inaktivität ausblenden
unclutter -idle 0.5 -root &

# Alte Chromium-Crash-Meldungen entfernen
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences 2>/dev/null || true
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences 2>/dev/null || true

# Kiosk URL - verwendet localhost da Scratch auf dem gleichen Pi läuft
KIOSK_URL="http://localhost:8000/kiosk.html"

# Chromium im Kiosk-Modus starten
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --no-first-run \
    --start-fullscreen \
    --autoplay-policy=no-user-gesture-required \
    --check-for-update-interval=604800 \
    --disable-component-update \
    "$KIOSK_URL"
KIOSK_EOF

chmod +x "$KIOSK_SCRIPT"
echo "✓ Kiosk-Script erstellt: $KIOSK_SCRIPT"

# Autostart für Kiosk einrichten
echo ""
echo "🚀 Richte Autostart ein..."

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/sidekick-kiosk.desktop" << EOF
[Desktop Entry]
Type=Application
Name=SIDEKICK Kiosk
Comment=Startet SIDEKICK im Kiosk-Modus
Exec=$KIOSK_SCRIPT
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo "✓ Autostart eingerichtet!"

# Optionale LXDE-Autostart Konfiguration (für ältere Pi OS Versionen)
LXDE_AUTOSTART="$HOME/.config/lxsession/LXDE-pi/autostart"
if [ -d "$(dirname "$LXDE_AUTOSTART")" ]; then
    echo ""
    echo "📝 Konfiguriere LXDE Autostart..."
    
    # Backup erstellen falls vorhanden
    if [ -f "$LXDE_AUTOSTART" ]; then
        cp "$LXDE_AUTOSTART" "$LXDE_AUTOSTART.backup"
    fi
    
    cat > "$LXDE_AUTOSTART" << EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xset s off
@xset s noblank
@xset -dpms
@unclutter -idle 0.5 -root
@$KIOSK_SCRIPT
EOF
    echo "✓ LXDE Autostart konfiguriert!"
fi

# Systemd Service als Alternative (für headless boot mit später Desktop-Start)
echo ""
echo "📝 Erstelle systemd Service (optional)..."

sudo tee /etc/systemd/system/sidekick-kiosk.service > /dev/null << EOF
[Unit]
Description=SIDEKICK Kiosk Display
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
User=$USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=$HOME/.Xauthority
ExecStartPre=/bin/sleep 10
ExecStart=$KIOSK_SCRIPT
Restart=on-failure
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

echo "✓ Systemd Service erstellt!"
echo "   (Nicht automatisch aktiviert - nutze 'sudo systemctl enable sidekick-kiosk' bei Bedarf)"

# Desktop-Shortcut zum Starten/Stoppen erstellen
echo ""
echo "🖥️  Erstelle Desktop-Shortcuts..."

DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR"

# Start Kiosk
cat > "$DESKTOP_DIR/SIDEKICK-Kiosk-Start.desktop" << EOF
[Desktop Entry]
Type=Application
Name=🖥️ Kiosk Starten
Comment=Startet den SIDEKICK Kiosk-Modus
Exec=$KIOSK_SCRIPT
Icon=video-display
Terminal=false
Categories=Utility;
EOF
chmod +x "$DESKTOP_DIR/SIDEKICK-Kiosk-Start.desktop"

# Stop Kiosk
cat > "$DESKTOP_DIR/SIDEKICK-Kiosk-Stop.desktop" << EOF
[Desktop Entry]
Type=Application
Name=🛑 Kiosk Beenden
Comment=Beendet den SIDEKICK Kiosk-Modus
Exec=bash -c "pkill -f 'chromium.*kiosk' && pkill unclutter; echo 'Kiosk beendet'"
Icon=process-stop
Terminal=true
Categories=Utility;
EOF
chmod +x "$DESKTOP_DIR/SIDEKICK-Kiosk-Stop.desktop"

echo "✓ Desktop-Shortcuts erstellt!"

# Zusammenfassung
echo ""
echo "========================================"
echo "  ✅ Kiosk-Setup abgeschlossen!"
echo "========================================"
echo ""
echo "Was wurde eingerichtet:"
echo "  • Chromium Kiosk-Script: $KIOSK_SCRIPT"
echo "  • Autostart bei Desktop-Login"
echo "  • Desktop-Shortcuts zum Starten/Stoppen"
echo ""
echo "So funktioniert's:"
echo "  1. Bei jedem Start des Desktops öffnet sich"
echo "     automatisch der Kiosk im Vollbild"
echo "  2. Der Kiosk wartet auf MQTT-Befehle vom Dashboard"
echo "  3. Über das Dashboard kannst du Projekte laden"
echo "     und starten"
echo ""
echo "Kiosk manuell starten:"
echo "  $KIOSK_SCRIPT"
echo ""
echo "Kiosk beenden:"
echo "  pkill -f 'chromium.*kiosk'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Jetzt neustarten um Kiosk zu testen? (j/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Jj]$ ]]; then
    echo "Starte neu..."
    sudo reboot
else
    echo ""
    echo "Du kannst später mit 'sudo reboot' neustarten."
    echo "Oder starte den Kiosk manuell mit: $KIOSK_SCRIPT"
fi
