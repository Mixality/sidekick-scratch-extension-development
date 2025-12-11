# Sidekick Assistenzsystem

Das Sidekick Assisstenzsystem unterstützt Menschen mit Einschränkungen bei prozeduralen Arbeitsabläufen, indem es für einzelnen Arbeitsschritte Anweisungen anzeigt.
Arbeitsabläufe können über die Programmieroberfläche Scratch erstellt werden. 


## Erstinstallations-Skript

Aktuell muss man Mosquitto und den Hotspot einmalig manuell einrichten (siehe Readme).
Nachfolgende automatisiert:

Komplettes Erstinstallations-Skript erstellen, das alles einrichtet:

## Übersicht der Skripte:

Skript	              Zweck
install-sidekick.sh	  Komplett-Installation (einmalig auf frischem Pi)
setup-autostart.sh	  Nur Autostart einrichten (wenn Rest schon da)
update-sidekick.sh	  Dateien aktualisieren

### Funktionalitäten von `install-sidekick.sh`:

- Mosquitto installieren & konfigurieren (Port 1883 + WebSocket 9001)
- Hotspot einrichten (mit eindeutigem Namen basierend auf Pi-Seriennummer)
- Python-Pakete installieren (paho-mqtt, rpi_ws281x, etc.)
- SIDEKICK-Dateien herunterladen (Python + Webapp)
- Autostart-Services einrichten
- Desktop-Shortcuts installieren

### Verwendung auf einem frischen Pi:

```shell
# Einzeiler zum Herunterladen und Ausführen:
curl -sSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/install-sidekick.sh | sudo bash
```

Oder:

```shell
wget https://raw.githubusercontent.com/.../install-sidekick.sh
sudo bash install-sidekick.sh
```

Danach: Pi neu starten --> Alles sollte automatisch laufen.

## Schnellstart (Raspberry Pi bereits eingerichtet)

Falls der Pi bereits eingerichtet ist, hier die wichtigsten Infos:

### Verbinden (Tablet/Laptop):
1. Mit WLAN verbinden: **SIDEKICK-RPi-...** (Passwort: `sidekick`)
2. Browser öffnen: **http://10.42.0.1:8000**
3. In Scratch: SIDEKICK-Extension → "Verbinde mit [ws://10.42.0.1:9001]"

### Dienste starten (falls nicht automatisch):
```bash
sudo systemctl start sidekick-webapp
sudo systemctl start sidekick-sensors
```

---

## Was wird benötigt?

- Raspberry Pi
- SD Karte
- Sichtlagerkästen
- Ultraschallsensor(en) mit Halterung (einer pro Sichtlagerkasten) 
- LED Strip zum Anbringen an Sichtlagerkästen (einer pro Sichtlagerkasten)
- Aufsetzplatine für Raspberry Pi

## Aufsetzen des Systems auf Raspberry Pi

[Raspberry Pi Imager](https://www.raspberrypi.com/software/) downloaden 

Raspberry Pi Imager öffnen

Für die Installation Raspberry Pi OS 32 Bit als Betriebssystem auswählen.

Sichergehen das SD Karte am Computer angeschlossen ist, diese in dem Dropdown Menü auswählen.

Auf SD Karte schreiben starten. Danach SD Karte in den Raspberry Pi stecken.

Raspberry Pi starten. 

Wenn nach Ändern des Passwort für Rasperry Pi OS gefragt wird: sidekick

Wenn danach gefragt wird, Updates installieren.

Wenn die Fehlermeldung auftaucht, dass das Image zu groß sei:
Im Terminal öffnen:
 ```
sudo raspi-config 
  ```

Hier dann auswählen:
option advanced settings/options -> expand file system

Nun sollte das Betriebssystem starten.

Damit die LEDs funktionieren müssen zwei Konfigurationdatei bearbeitet werden:

1.

Öffne /etc/modprobe.d/snd-blacklist.conf (mit sudo)

und füge
```
blacklist snd_bcm2835
```
am Ende der Datei hinzu.

2.
Öffne /boot/config.txt (mit sudo)

Such in der Datei die Stelle:

```
# Enable audio (loads snd_bcm2835)
dtparam=audio=on
```
und ändere sie wie folgt:

```
# Enable audio (loads snd_bcm2835)
# dtparam=audio=on
```

Danach den Raspberry Pi neustarten.

Das Git-Repository in ~/ clonen:

```
cd ~/
git clone https://github.com/Mixality/Sidekick
```

Die Click-Script Datei auf Desktop verschieben

Dependencies installieren:

**Für neuere Raspberry Pi OS Versionen (Bookworm / Debian 12+):**
```
sudo apt install python3-pynput
sudo apt install python3-paho-mqtt
sudo pip3 install rpi_ws281x --break-system-packages
```

**Für ältere Raspberry Pi OS Versionen (Bullseye / Debian 11 und älter):**
```
sudo pip3 install rpi_ws281x
sudo pip3 install pynput
sudo pip3 install paho-mqtt
```

### MQTT Konfiguration (Optional)

Das System unterstützt jetzt MQTT für die Kommunikation mit Scratch. Die Konfiguration findest du in `python/SmartBox.py`:

```python
MQTT_BROKER = "localhost"  # IP/Hostname deines MQTT-Brokers
MQTT_PORT = 1883
MQTT_TOPIC_BASE = "sidekick/box"
MQTT_ENABLED = True  # Auf False setzen, um MQTT zu deaktivieren
```

**Topic-Struktur:** `sidekick/box/{box_nr}/hand_detected`

Beispiel: Wenn eine Hand in Box 3 erkannt wird, wird eine Nachricht an `sidekick/box/3/hand_detected` gesendet.

**MQTT-Broker installieren (falls noch nicht vorhanden):**
```
sudo apt-get install mosquitto mosquitto-clients
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
```

Scratch Installieren
```
$ sudo apt-get update
$ sudo apt-get install scratch3
```

## RPi
```
sudo nano /etc/mosquitto/mosquitto.conf
```

```conf
# Anonyme Verbindungen erlauben
allow_anonymous true

# WebSocket Listener
listener 9001
protocol websockets
```

```
sudo systemctl restart mosquitto
```

```
cat /proc/cpuinfo
```

<!-- ```
nmcli device wifi hotspot ssid "SIDEKICK-Hotspot-RPi-4B-c03114-100000005f7b6f00" password "sidekick"
``` -->

```
nmcli device wifi hotspot ssid "SIDEKICK-RPi-100000005f7b6f00" password "sidekick"
```

```
nmcli connection show
```

```
nmcli connection modify Hotspot autoconnect yes
```

```sh
nmcli connection modify Hotspot connection.autoconnect-priority 100
```

---

## Autostart einrichten (WICHTIG!)

Damit nach jedem Neustart alles automatisch läuft:

### Option A: Setup-Skript verwenden (empfohlen)

```bash
# Skript herunterladen (falls nicht vorhanden)
curl -sSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/setup-autostart.sh -o ~/setup-autostart.sh

# Ausführen
sudo bash ~/setup-autostart.sh
```

Das Skript erstellt zwei systemd-Services:
- **sidekick-webapp**: HTTP-Server für die Scratch-Webapp
- **sidekick-sensors**: ScratchConnect.py für Sensoren/LEDs

### Option B: Manuell einrichten

#### 1. HTTP-Server Service

```bash
sudo nano /etc/systemd/system/sidekick-webapp.service
```

Inhalt:
```ini
[Unit]
Description=SIDEKICK Scratch Webapp HTTP Server
After=network.target mosquitto.service

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/Sidekick/sidekick-scratch-extension-development-gh-pages/scratch
ExecStart=/usr/bin/python3 -m http.server 8000 --bind 0.0.0.0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

#### 2. Sensor Service

```bash
sudo nano /etc/systemd/system/sidekick-sensors.service
```

Inhalt:
```ini
[Unit]
Description=SIDEKICK ScratchConnect Sensor Service
After=network.target mosquitto.service

[Service]
Type=simple
User=root
WorkingDirectory=/home/pi/Sidekick/python
ExecStart=/usr/bin/python3 /home/pi/Sidekick/python/ScratchConnect.py
Restart=always
RestartSec=5
ExecStartPre=/bin/sleep 3

[Install]
WantedBy=multi-user.target
```

#### 3. Services aktivieren

```bash
sudo systemctl daemon-reload
sudo systemctl enable sidekick-webapp
sudo systemctl enable sidekick-sensors
sudo systemctl start sidekick-webapp
sudo systemctl start sidekick-sensors
```

### Service-Verwaltung

```bash
# Status prüfen
sudo systemctl status sidekick-webapp
sudo systemctl status sidekick-sensors

# Logs ansehen (live)
sudo journalctl -u sidekick-webapp -f
sudo journalctl -u sidekick-sensors -f

# Neu starten
sudo systemctl restart sidekick-webapp
sudo systemctl restart sidekick-sensors

# Stoppen
sudo systemctl stop sidekick-webapp
sudo systemctl stop sidekick-sensors
```

---

## SIDEKICK aktualisieren

Um die neuesten Dateien vom GitHub herunterzuladen:

```bash
# Update-Skript herunterladen und ausführen
curl -sSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/update-sidekick.sh | bash
```

Oder manuell:

```bash
# Python-Skripte (main Branch)
cd ~/Sidekick/python
curl -sSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/python/ScratchConnect.py -o ScratchConnect.py
curl -sSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/python/SmartBox.py -o SmartBox.py

# Webapp (gh-pages Branch) - als ZIP
cd ~/Sidekick
rm -rf sidekick-scratch-extension-development-gh-pages
curl -sSL https://github.com/Mixality/sidekick-scratch-extension-development/archive/refs/heads/gh-pages.zip -o gh-pages.zip
unzip gh-pages.zip
rm gh-pages.zip

# Services neu starten
sudo systemctl restart sidekick-webapp sidekick-sensors
```

---

## Offline-Betrieb (kein Internet nötig!)

Das System ist für den **vollständigen Offline-Betrieb** konzipiert:

1. **Raspberry Pi als Hotspot**: Der Pi erstellt sein eigenes WLAN-Netzwerk
2. **Lokaler HTTP-Server**: Die Scratch-Webapp läuft direkt auf dem Pi
3. **Lokaler MQTT-Broker**: Mosquitto läuft auf dem Pi

**Ablauf:**
1. Pi einschalten → Hotspot, Webapp & Sensoren starten automatisch
2. Tablet/Laptop mit "SIDEKICK-RPi-..." WLAN verbinden
3. Browser: http://10.42.0.1:8000 öffnen
4. Fertig! Keine Internetverbindung erforderlich.

---

## Verwendung

### Auf dem RPi (manuell, falls Autostart nicht eingerichtet):

```sh
# HTTP-Server starten
python3 -m http.server -d ~/Sidekick/sidekick-scratch-extension-development-gh-pages/scratch

# In einem anderen Terminal: Sensoren starten
sudo python3 ~/Sidekick/python/ScratchConnect.py
```

### Auf Tablet/Laptop:

1. Mit WLAN verbinden:
   - SSID: **SIDEKICK-RPi-100000005f7b6f00** (kann abweichen)
   - Password: **sidekick**

2. Browser öffnen: **http://10.42.0.1:8000**

3. In Scratch SIDEKICK-Extension laden und verbinden:
   - `Verbinde mit [ws://10.42.0.1:9001]`

4. Hat-Block für Sensor-Events erstellen:
   - Topic-Beispiel: `sidekick/box/1/hand_detected`

---

## Development

### Home LAN Development Connection:

1. **Setup A**: Alles vom RPi
   - Browser: http://192.168.178.117:8000/
   - Broker: ws://192.168.178.117:9001
  
2. **Setup B**: Webapp auf PC, Broker auf RPi
   - Auf dem PC:
     1. `./2-build.ps1`
     2. `./3-run-private.ps1`
   - Browser: http://localhost:8000/
   - Broker: ws://192.168.178.117:9001

### Statische IP für RPi im LAN:

```shell
sudo nmcli connection modify "Wired connection 1" ipv4.addresses 192.168.178.117/24
sudo nmcli connection modify "Wired connection 1" ipv4.gateway 192.168.178.1
sudo nmcli connection modify "Wired connection 1" ipv4.dns "192.168.178.1"
sudo nmcli connection modify "Wired connection 1" ipv4.method manual
sudo nmcli connection up "Wired connection 1"
```

---

## Hinweise

- Im **Hotspot-Modus** ist die IP immer `10.42.0.1`
- **Mosquitto** (MQTT-Broker) startet automatisch beim Booten
- Die Python-Skripte stammen ursprünglich von: https://github.com/Mixality/Sidekick/tree/main/python
