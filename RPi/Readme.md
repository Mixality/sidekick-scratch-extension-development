# Sidekick Assistenzsystem

Das Sidekick Assisstenzsystem unterstützt Menschen mit Einschränkungen bei prozeduralen Arbeitsabläufen, indem es für einzelnen Arbeitsschritte Anweisungen anzeigt.
Arbeitsabläufe können über die Programmieroberfläche Scratch erstellt werden. 

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

### PI:

- Set up MQTT connection.

- Set up sensor (messages):
  - Start the Python script on the RPi:
    ```sh
    sudo python3 ~/Sidekick/python/ScratchConnect.py
    ```
    - Python script origin / source: https://github.com/Mixality/Sidekick/tree/main/python

- In Scratch: Create a Hat block listening on the topic (example here: Box 1, ultrasonic hand detection):
  - `sidekick/box/1/hand_detected`

- Download published Scratch webapp (on GitHub Pages, modified version with SIDEKICK extentions):
  - https://github.com/Mixality/sidekick-scratch-extension-development/tree/gh-pages

- Run the webapp private / locally:

  ```sh
  python3 -m http.server -d sidekick-scratch-extension-development-gh-pages/scratch
  ```
  
  - Open webapp via: http://0.0.0.0:8000/

### Tablet etc.:
  - Use Wi-Fi (Hotspot):
    - SSID: **SIDEKICK-RPi-100000005f7b6f00**
    - Password: **sidekick**
  - Open webapp:
    - Via: http://10.42.0.1:8000




ws://10.42.0.1:9001




## IP Address Setup

### During Development:

- Development setup, via LAN, with 192.168.178.x
  - Problem: Dynamic DHCP IP assignment
  - Possible solution: Static IP configuration  on the RPi:

  ```shell
  sudo nmcli connection modify "Wired connection 1" ipv4.addresses 192.168.178.117/24
  sudo nmcli connection modify "Wired connection 1" ipv4.gateway 192.168.178.1
  sudo nmcli connection modify "Wired connection 1" ipv4.dns "192.168.178.1"
  sudo nmcli connection modify "Wired connection 1" ipv4.method manual
  sudo nmcli connection up "Wired connection 1"
  ```

### For Release Version / End User:

- The RPi is router, in hotspot mode
  - Thus, its gateway IP (ws://10.42.0.1:9001) always stays the same
