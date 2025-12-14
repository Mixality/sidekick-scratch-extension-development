#!/bin/bash
# =============================================================================
# SIDEKICK Update Script
# =============================================================================
# Aktualisiert die SIDEKICK-Dateien von GitHub Releases
#
# Verwendung:
#   ./update-sidekick.sh          → Lädt neuestes stabiles Release
#   ./update-sidekick.sh --pre    → Lädt auch Pre-Releases (für Entwicklung/Tests)
#   ./update-sidekick.sh --dev    → Alias für --pre
#   ./update-sidekick.sh --help   → Zeigt diese Hilfe
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Konfiguration
# -----------------------------------------------------------------------------
GITHUB_REPO="Mixality/sidekick-scratch-extension-development"
USER_HOME="$HOME"
SIDEKICK_DIR="$USER_HOME/Sidekick"
WEBAPP_DIR="$SIDEKICK_DIR/sidekick"
PYTHON_DIR="$SIDEKICK_DIR/python"
SCRIPTS_DIR="$SIDEKICK_DIR/scripts"

# Standard: nur stabile Releases
INCLUDE_PRERELEASE=false

# -----------------------------------------------------------------------------
# Argumente verarbeiten
# -----------------------------------------------------------------------------
show_help() {
    echo "SIDEKICK Update Script"
    echo ""
    echo "Verwendung:"
    echo "  ./update-sidekick.sh          Lädt neuestes stabiles Release"
    echo "  ./update-sidekick.sh --pre    Lädt auch Pre-Releases (Test-Versionen)"
    echo "  ./update-sidekick.sh --dev    Alias für --pre"
    echo "  ./update-sidekick.sh --help   Zeigt diese Hilfe"
    echo ""
    echo "Pre-Releases haben Tags wie: v1.0.1-test1, v1.0.1-dev, v1.0.1-beta"
    exit 0
}

for arg in "$@"; do
    case $arg in
        --pre|--dev|--test)
            INCLUDE_PRERELEASE=true
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unbekannte Option: $arg"
            echo "Verwende --help für Hilfe"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Funktionen
# -----------------------------------------------------------------------------
get_latest_release() {
    if [ "$INCLUDE_PRERELEASE" = true ]; then
        # Hole alle Releases (inklusive Pre-Releases), nimm das erste (neueste)
        curl -sSL "https://api.github.com/repos/$GITHUB_REPO/releases" | \
            grep -m 1 '"tag_name":' | \
            sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
    else
        # Hole nur das neueste stabile Release
        curl -sSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | \
            grep '"tag_name":' | \
            sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
    fi
}

get_current_version() {
    if [ -f "$SIDEKICK_DIR/VERSION" ]; then
        cat "$SIDEKICK_DIR/VERSION"
    else
        echo "nicht installiert"
    fi
}

# -----------------------------------------------------------------------------
# Start
# -----------------------------------------------------------------------------
echo "=============================================="
echo "  SIDEKICK Update"
echo "=============================================="
echo ""

if [ "$INCLUDE_PRERELEASE" = true ]; then
    echo "Modus: Inklusive Pre-Releases (Test/Dev)"
else
    echo "Modus: Nur stabile Releases"
fi
echo ""

# Prüfen ob Sidekick-Ordner existiert
if [ ! -d "$SIDEKICK_DIR" ]; then
    echo "Sidekick-Ordner nicht gefunden. Erstelle..."
    mkdir -p "$SIDEKICK_DIR"
fi

cd "$SIDEKICK_DIR"

# -----------------------------------------------------------------------------
# 1. Aktuelle und neueste Version ermitteln
# -----------------------------------------------------------------------------
echo "[1/4] Prüfe Versionen..."

CURRENT_VERSION=$(get_current_version)
echo "   Installierte Version: $CURRENT_VERSION"

LATEST_VERSION=$(get_latest_release)
if [ -z "$LATEST_VERSION" ]; then
    echo "   FEHLER: Konnte neueste Version nicht ermitteln!"
    echo "   Prüfe deine Internetverbindung."
    exit 1
fi
echo "   Neueste Version: $LATEST_VERSION"

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo ""
    echo "   ✓ Du hast bereits die neueste Version!"
    echo ""
    read -p "   Trotzdem neu installieren? (j/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        echo "   Update abgebrochen."
        exit 0
    fi
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Release herunterladen
# -----------------------------------------------------------------------------
echo "[2/4] Lade Release $LATEST_VERSION herunter..."

DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_VERSION/sidekick-$LATEST_VERSION.zip"
TEMP_ZIP="$SIDEKICK_DIR/sidekick-update.zip"
TEMP_DIR="$SIDEKICK_DIR/sidekick-update-temp"

# Download
if ! curl -sSL "$DOWNLOAD_URL" -o "$TEMP_ZIP"; then
    echo "   FEHLER: Download fehlgeschlagen!"
    echo "   URL: $DOWNLOAD_URL"
    exit 1
fi

echo "   ✓ Download abgeschlossen"

# -----------------------------------------------------------------------------
# 3. Backup und Installation
# -----------------------------------------------------------------------------
echo "[3/4] Installiere Update..."

# Sichere Benutzer-Dateien (Projekte, Videos)
BACKUP_DIR="$SIDEKICK_DIR/.backup_temp"
if [ -d "$WEBAPP_DIR/projects" ] || [ -d "$WEBAPP_DIR/videos" ]; then
    echo "   Sichere Projekte und Videos..."
    mkdir -p "$BACKUP_DIR"
    [ -d "$WEBAPP_DIR/projects" ] && cp -r "$WEBAPP_DIR/projects" "$BACKUP_DIR/"
    [ -d "$WEBAPP_DIR/videos" ] && cp -r "$WEBAPP_DIR/videos" "$BACKUP_DIR/"
fi

# Entpacken
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"
rm -f "$TEMP_ZIP"

# Alte Dateien entfernen und neue kopieren
rm -rf "$WEBAPP_DIR"
rm -rf "$PYTHON_DIR"
rm -rf "$SCRIPTS_DIR"

# Neue Dateien installieren
mv "$TEMP_DIR/sidekick" "$WEBAPP_DIR"
mv "$TEMP_DIR/python" "$PYTHON_DIR"
mv "$TEMP_DIR/scripts" "$SCRIPTS_DIR" 2>/dev/null || true

# VERSION-Datei speichern
cp "$TEMP_DIR/VERSION" "$SIDEKICK_DIR/VERSION" 2>/dev/null || echo "$LATEST_VERSION" > "$SIDEKICK_DIR/VERSION"

# Update-Script aktualisieren (sich selbst)
if [ -f "$SCRIPTS_DIR/update-sidekick.sh" ]; then
    cp "$SCRIPTS_DIR/update-sidekick.sh" "$SIDEKICK_DIR/update-sidekick.sh"
    chmod +x "$SIDEKICK_DIR/update-sidekick.sh"
fi

# Aufräumen
rm -rf "$TEMP_DIR"

# Stelle Benutzer-Dateien wieder her
if [ -d "$BACKUP_DIR" ]; then
    echo "   Stelle Projekte und Videos wieder her..."
    [ -d "$BACKUP_DIR/projects" ] && cp -r "$BACKUP_DIR/projects" "$WEBAPP_DIR/"
    [ -d "$BACKUP_DIR/videos" ] && cp -r "$BACKUP_DIR/videos" "$WEBAPP_DIR/"
    rm -rf "$BACKUP_DIR"
fi

# Stelle sicher dass die Ordner existieren
mkdir -p "$WEBAPP_DIR/projects"
mkdir -p "$WEBAPP_DIR/videos"

# Skripte ausführbar machen
chmod +x "$SIDEKICK_DIR"/*.sh 2>/dev/null || true
chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

echo "   ✓ Installation abgeschlossen"

# -----------------------------------------------------------------------------
# 4. Services neu starten
# -----------------------------------------------------------------------------
echo "[4/4] Starte Services neu..."

# Restart services if they are currently running
if systemctl is-active --quiet sidekick-webapp 2>/dev/null; then
    sudo systemctl restart sidekick-webapp
    echo "   ✓ sidekick-webapp neu gestartet"
fi

if systemctl is-active --quiet sidekick-sensors 2>/dev/null; then
    sudo systemctl restart sidekick-sensors
    echo "   ✓ sidekick-sensors neu gestartet"
fi

if systemctl is-active --quiet sidekick-dashboard 2>/dev/null; then
    sudo systemctl restart sidekick-dashboard
    echo "   ✓ sidekick-dashboard neu gestartet"
fi

# -----------------------------------------------------------------------------
# Fertig!
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  ✅ Update auf $LATEST_VERSION abgeschlossen!"
echo "=============================================="
echo ""
