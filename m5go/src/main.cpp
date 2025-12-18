/**
 * SIDEKICK M5GO Firmware
 * =======================
 * 
 * Für M5Stack M5GO IoT Starter Kit V2.7
 * 
 * Funktionen:
 * - Button A (links):   Nummer runter (4 → 3 → 2 → 1 → 4...)
 * - Button C (rechts):  Nummer hoch (1 → 2 → 3 → 4 → 1...)
 * - Button B (mitte):   Sendet pressed/released für gewählte Nummer
 * 
 * MQTT Topics:
 * - sidekick/button/1/state → "pressed" / "released"
 * - sidekick/button/2/state → "pressed" / "released"
 * - sidekick/button/3/state → "pressed" / "released"
 * - sidekick/button/4/state → "pressed" / "released"
 * - sidekick/m5go/status → Verbindungsstatus
 */

#include <M5Unified.h>
#include <WiFi.h>
#include <PubSubClient.h>

// =============================================================================
// Konfiguration - Bei Bedarf anpassen!
// =============================================================================

// WLAN Zugangsdaten (SIDEKICK Hotspot)
const char* WIFI_SSID = "sidekick-rpi-2";
const char* WIFI_PASSWORD = "sidekick";

// MQTT Broker (Raspberry Pi im Hotspot-Modus)
const char* MQTT_SERVER = "10.42.0.1";
const int MQTT_PORT = 1883;

// =============================================================================
// Globale Variablen
// =============================================================================

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

int currentButtonNumber = 1;  // Aktuelle Button-Nummer (cyclet 1-99)
bool lastButtonBState = false; // Für pressed/released Erkennung

unsigned long lastReconnectAttempt = 0;

// Farben
const uint32_t COLOR_BG = TFT_BLACK;
const uint32_t COLOR_CONNECTED = TFT_GREEN;
const uint32_t COLOR_DISCONNECTED = TFT_RED;
const uint32_t COLOR_BUTTON_ACTIVE = TFT_YELLOW;
const uint32_t COLOR_NUMBER = TFT_WHITE;
const uint32_t COLOR_ARROW = TFT_CYAN;

// =============================================================================
// Funktions-Deklarationen
// =============================================================================

void connectWiFi();
bool connectMQTT();
void updateDisplay();
void publishButtonState(const char* state);
void drawArrow(int x, int y, bool left);

// =============================================================================
// Setup
// =============================================================================

void setup() {
    // M5Unified initialisieren
    auto cfg = M5.config();
    cfg.serial_baudrate = 115200;
    M5.begin(cfg);
    
    Serial.println("\n=== SIDEKICK M5GO Firmware ===");
    Serial.println("Button A: Nummer -");
    Serial.println("Button B: Event senden");
    Serial.println("Button C: Nummer +");
    
    // Display Setup
    M5.Display.setRotation(1);  // Landscape
    M5.Display.fillScreen(COLOR_BG);
    M5.Display.setTextColor(TFT_WHITE, COLOR_BG);
    M5.Display.setTextSize(2);
    M5.Display.setCursor(10, 10);
    M5.Display.println("SIDEKICK M5GO");
    M5.Display.println("Verbinde...");
    
    // WiFi verbinden
    connectWiFi();
    
    // MQTT Setup
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    
    // Initial Display
    updateDisplay();
}

// =============================================================================
// Loop
// =============================================================================

void loop() {
    M5.update();
    
    // MQTT Verbindung prüfen
    if (!mqttClient.connected()) {
        unsigned long now = millis();
        if (now - lastReconnectAttempt > 5000) {
            lastReconnectAttempt = now;
            if (connectMQTT()) {
                lastReconnectAttempt = 0;
            }
        }
    } else {
        mqttClient.loop();
    }
    
    // ========== Button A: Nummer runter ==========
    if (M5.BtnA.wasPressed()) {
        currentButtonNumber--;
        if (currentButtonNumber < 1) currentButtonNumber = 99;
        Serial.printf("Button-Nummer: %d\n", currentButtonNumber);
        updateDisplay();
    }
    
    // ========== Button C: Nummer hoch ==========
    if (M5.BtnC.wasPressed()) {
        currentButtonNumber++;
        if (currentButtonNumber > 99) currentButtonNumber = 1;
        Serial.printf("Button-Nummer: %d\n", currentButtonNumber);
        updateDisplay();
    }
    
    // ========== Button B: Event senden ==========
    if (M5.BtnB.wasPressed()) {
        Serial.printf("Button %d PRESSED\n", currentButtonNumber);
        publishButtonState("pressed");
        lastButtonBState = true;
        
        // Visuelles Feedback
        M5.Display.fillRect(100, 80, 120, 80, COLOR_BUTTON_ACTIVE);
        M5.Display.setTextSize(6);
        M5.Display.setTextColor(TFT_BLACK, COLOR_BUTTON_ACTIVE);
        M5.Display.setCursor(140, 100);
        M5.Display.printf("%d", currentButtonNumber);
    }
    
    if (M5.BtnB.wasReleased()) {
        if (lastButtonBState) {
            Serial.printf("Button %d RELEASED\n", currentButtonNumber);
            publishButtonState("released");
            lastButtonBState = false;
            updateDisplay();  // Zurück zur normalen Anzeige
        }
    }
    
    delay(10);
}

// =============================================================================
// WiFi Verbindung
// =============================================================================

void connectWiFi() {
    Serial.printf("Verbinde zu WiFi: %s\n", WIFI_SSID);
    
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
        
        // Display Update
        M5.Display.setCursor(10, 50);
        M5.Display.printf("WiFi: %d/30", attempts);
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi verbunden!");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println("\nWiFi Fehler!");
    }
}

// =============================================================================
// MQTT Verbindung
// =============================================================================

bool connectMQTT() {
    Serial.println("Verbinde zu MQTT...");
    
    // Client-ID mit MAC-Adresse für Eindeutigkeit
    String clientId = "M5GO-" + String((uint32_t)ESP.getEfuseMac(), HEX);
    
    if (mqttClient.connect(clientId.c_str())) {
        Serial.println("MQTT verbunden!");
        
        // Status publizieren
        mqttClient.publish("sidekick/m5go/status", "connected");
        
        updateDisplay();
        return true;
    } else {
        Serial.printf("MQTT Fehler: %d\n", mqttClient.state());
        updateDisplay();
        return false;
    }
}

// =============================================================================
// Button-Event publizieren
// =============================================================================

void publishButtonState(const char* state) {
    if (!mqttClient.connected()) {
        Serial.println("MQTT nicht verbunden - Event verworfen");
        return;
    }
    
    char topic[64];
    snprintf(topic, sizeof(topic), "sidekick/button/%d/state", currentButtonNumber);
    
    mqttClient.publish(topic, state);
    Serial.printf("MQTT: %s → %s\n", topic, state);
}

// =============================================================================
// Display aktualisieren
// =============================================================================

void updateDisplay() {
    M5.Display.fillScreen(COLOR_BG);
    
    // Titel
    M5.Display.setTextSize(2);
    M5.Display.setTextColor(TFT_WHITE, COLOR_BG);
    M5.Display.setCursor(80, 5);
    M5.Display.print("SIDEKICK");
    
    // Verbindungsstatus
    M5.Display.setTextSize(1);
    if (WiFi.status() == WL_CONNECTED) {
        if (mqttClient.connected()) {
            M5.Display.setTextColor(COLOR_CONNECTED, COLOR_BG);
            M5.Display.setCursor(100, 25);
            M5.Display.print("Verbunden");
        } else {
            M5.Display.setTextColor(COLOR_DISCONNECTED, COLOR_BG);
            M5.Display.setCursor(85, 25);
            M5.Display.print("MQTT getrennt");
        }
    } else {
        M5.Display.setTextColor(COLOR_DISCONNECTED, COLOR_BG);
        M5.Display.setCursor(85, 25);
        M5.Display.print("WiFi getrennt");
    }
    
    // Pfeile für Navigation
    M5.Display.setTextSize(4);
    M5.Display.setTextColor(COLOR_ARROW, COLOR_BG);
    M5.Display.setCursor(30, 100);
    M5.Display.print("<");  // Links = runter
    M5.Display.setCursor(270, 100);
    M5.Display.print(">");  // Rechts = hoch
    
    // Große Button-Nummer in der Mitte
    M5.Display.fillRect(100, 70, 120, 100, TFT_DARKGREY);
    M5.Display.setTextSize(8);
    M5.Display.setTextColor(COLOR_NUMBER, TFT_DARKGREY);
    M5.Display.setCursor(140, 85);
    M5.Display.printf("%d", currentButtonNumber);
    
    // Button-Beschriftungen unten
    M5.Display.setTextSize(1);
    M5.Display.setTextColor(TFT_LIGHTGREY, COLOR_BG);
    M5.Display.setCursor(25, 225);
    M5.Display.print("Nr -");
    M5.Display.setCursor(135, 225);
    M5.Display.print("SENDEN");
    M5.Display.setCursor(260, 225);
    M5.Display.print("Nr +");
    
    // Topic-Info
    M5.Display.setCursor(50, 185);
    M5.Display.printf("Topic: sidekick/button/%d/state", currentButtonNumber);
}
