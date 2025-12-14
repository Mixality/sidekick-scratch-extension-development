# SIDEKICK Scratch Extension Development

https://mixality.github.io/sidekick-scratch-extension-development/scratch/


## Aufbau

- Der HTTP-Server auf Port 8000 hostet den scratch-Ordner unter "/home/sidekick/Sidekick/sidekick-scratch-extension-development-gh-pages/scratch/"
  - Die Videos liegen in Ordner "/home/sidekick/Sidekick/sidekick-scratch-extension-development-gh-pages/scratch/videos/"
- Der HTTP-Server auf Port 8080 hostet das SIDEKICK-Dashboard.



--> Videos sind unter http://10.42.0.1:8000/videos/... erreichbar.
--> Scratch kann die Videos direkt laden (gleicher Origin --> keine CORS-Probleme etc.).
--> Die Video-URLs im Scratch-Projekt sind relativ zum Server und funktionieren dadurch.
--> Das SIDEKICK-Dashboard (auf Port 8080) dient ausschließlich als Verwaltungsoberfläche
    --> Es nimmt Uploads entgegen und speichert sie in den entsprechenden Ordner.
    --> Die eigentlichen Dateien werden darauf vom Scratch-Server (8000) ausgeliefert.

### Übersicht und Zugriff der aktiven Dienste

Port:   Dienst:                         Zweck:
8000	Scratch-Web-App-HTTP-Server	    Webapp + Videos + Projekte ausliefern
8080	SIDEKICK-Dashboard              Upload-Oberfläche, (Projekt-)Verwaltung
1883	MQTT (TCP)	                    Sensor-Kommunikation
9001	MQTT (WebSocket)	            Browser-MQTT-Verbindung

USB-Watcher: USB-StickÜberwachung für Auto-Import.

### Ordnerstruktur-Übersicht

/home/sidekick/Sidekick/
├── videos/           <-- Assistenz-Videos
├── projects/         <-- Scratch-Projekte ('.sb3'-Dateien)
├── scratch-webapp/   <-- Scratch-Editor
└── dashboard/        <-- SIDEKICK-Dashboard

### Übersicht zu Komponenten und Kommunikation

┌──────────────────────────────────────────────────────┐
│                    Raspberry Pi                      │
│  ┌────────────────────────────────────────────────┐  │
│  │  /home/sidekick/Sidekick/                      │  │
│  │  ├── videos/          <-- Videos hier ablegen  │  │
│  │  │   ├── anleitung1.mp4                        │  │
│  │  │   ├── schritt2.mp4                          │  │
│  │  │   └── ...                                   │  │
│  │  └── scratch-webapp/   <-- Scratch läuft hier  │  │
│  └────────────────────────────────────────────────┘  │
│                         │                            │
│           HTTP-Server (Port 8000)                    │
│           serviert alles (Webapp, Videodateien)      │
└──────────────────────────────────────────────────────┘
                          │
                     WLAN-Hotspot
                          │
              ┌───────────┴───────────┐
              │                       │
        ┌─────┴─────┐           ┌─────┴─────┐
        │  Tablet   │           │  Laptop   │
        │           │           │           │
        │ Browser:  │           │ Browser:  │
        │ 10.42.0.1 │           │ 10.42.0.1 │
        └───────────┘           └───────────┘

## Ablauf

### Beispiel

Der Ablauf wäre:
1. User öffnet Dashboard auf Tablet.
2. Lädt / wählt ein Projekt.
3. Klickt "Auf Display starten"
4. Pi-Display zeigt das Projekt im Player-Modus
5. Grüne Flagge kann über Dashboard oder sogar über einen Hardware-Button am Pi gedrückt werden

## Workflow

(Ziel, Befehl)
- Entwickeln / Testen: `git tag v1.0.1-test1` --> `git push origin v1.0.1-test1`
- RPi updaten (Test): `update-sidekick.sh --pre`
- Stabile Version: `git tag v1.0.1` --> `git push origin v1.0.1`
- RPi updaten (Stable): `update-sidekick.sh`


### Update und Installation

(Script, Stable, Pre-Release)
- 'install-sidekick.sh':
  - Stable: Standard
  - Pre-Release: --pre
- 'update-sidekick.sh':
  - Stable: Standard
  - Pre-Release: --pre


## Referenz

- `-s`: bash liest von stdin (pipe)
- `--`: "hier folgen Argumente für das Script (nicht für bash ...)"

"Normale" Installation / Update:

```shell
curl ... | sudo bash
```

Mit Pre-Releases:

```shell
curl ... | sudo bash -s -- --pre
```

Force (Neuinstallation):

```shell
curl ... | sudo bash -s -- --force
```

Kombiniert:

```shell
curl ... | sudo bash -s -- --pre --force
```
