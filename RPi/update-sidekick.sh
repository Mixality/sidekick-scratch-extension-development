#!/bin/bash
# =============================================================================
# SIDEKICK Update Script
# =============================================================================
# Aktualisiert die SIDEKICK-Dateien vom GitHub Repository
#
# Verwendung: bash update-sidekick.sh
# =============================================================================

set -e

echo "=============================================="
echo "  SIDEKICK Update"
echo "=============================================="
echo ""

USER_HOME="$HOME"
SIDEKICK_DIR="$USER_HOME/Sidekick"

# Pruefen ob Sidekick-Ordner existiert
if [ ! -d "$SIDEKICK_DIR" ]; then
    echo "Sidekick-Ordner nicht gefunden. Erstelle..."
    mkdir -p "$SIDEKICK_DIR"
fi

cd "$SIDEKICK_DIR"

# -----------------------------------------------------------------------------
# 1. Python-Skripte aktualisieren (main branch)
# -----------------------------------------------------------------------------
echo "[1/2] Aktualisiere Python-Skripte..."

PYTHON_DIR="$SIDEKICK_DIR/python"
REPO_URL="https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/main/RPi/python"

mkdir -p "$PYTHON_DIR"

# Dateien herunterladen
curl -sSL "$REPO_URL/ScratchConnect.py" -o "$PYTHON_DIR/ScratchConnect.py"
curl -sSL "$REPO_URL/SmartBox.py" -o "$PYTHON_DIR/SmartBox.py"
curl -sSL "$REPO_URL/neopixel.py" -o "$PYTHON_DIR/neopixel.py"
curl -sSL "$REPO_URL/SimpleLED.py" -o "$PYTHON_DIR/SimpleLED.py"
curl -sSL "$REPO_URL/sidekick-dashboard.py" -o "$PYTHON_DIR/sidekick-dashboard.py"
curl -sSL "$REPO_URL/generate-video-list.py" -o "$PYTHON_DIR/generate-video-list.py"

echo "   Abgeschlossen: Python-Skripte aktualisiert"

# -----------------------------------------------------------------------------
# 2. Webapp aktualisieren (gh-pages branch)
# -----------------------------------------------------------------------------
echo "[2/2] Aktualisiere Webapp..."

WEBAPP_DIR="$SIDEKICK_DIR/sidekick-scratch-extension-development-gh-pages"

# Falls der Ordner existiert, entfernen
if [ -d "$WEBAPP_DIR" ]; then
    rm -rf "$WEBAPP_DIR"
fi

# gh-pages Branch als ZIP herunterladen und entpacken
cd "$SIDEKICK_DIR"
curl -sSL "https://github.com/Mixality/sidekick-scratch-extension-development/archive/refs/heads/gh-pages.zip" -o gh-pages.zip
unzip -q gh-pages.zip
mv sidekick-scratch-extension-development-gh-pages "$WEBAPP_DIR" 2>/dev/null || true
rm -f gh-pages.zip

echo "   Abgeschlossen: Webapp aktualisiert"

# -----------------------------------------------------------------------------
# Services neu starten (falls vorhanden)
# -----------------------------------------------------------------------------
echo ""
echo "Starte Services neu..."

if systemctl is-active --quiet sidekick-webapp 2>/dev/null; then
    sudo systemctl restart sidekick-webapp
    echo "   Abgeschlossen: sidekick-webapp neu gestartet"
fi

if systemctl is-active --quiet sidekick-sensors 2>/dev/null; then
    sudo systemctl restart sidekick-sensors
    echo "   Abgeschlossen: sidekick-sensors neu gestartet"
fi

echo ""
echo "=============================================="
echo "  Update abgeschlossen!"
echo "=============================================="
echo ""
