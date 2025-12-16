/**
 * SIDEKICK M5StickC Firmware
 * ==========================
 * 
 * Verbindet sich mit dem SIDEKICK Hotspot und sendet Button-Events via MQTT.
 * 
 * Hardware: M5StickC (ESP32-basiert)
 * 
 * Funktionen:
 * - Button A (großer Button): Sendet pressed/released für gewählte Nummer
 * - Button B (seitlicher Button kurz): Wechselt die Button-Nummer hoch (1→2→3→4→1...)
 * - Button B (lang gedrückt): Wechselt die Button-Nummer runter
 * 
 * MQTT Topics:
 * - sidekick/button/1/state → "pressed" / "released"
 * - sidekick/button/2/state → "pressed" / "released"
 * - etc.
 * 
 * Installation:
 * 1. Arduino IDE öffnen
 * 2. M5StickC Board installieren (ESP32 Boards)
 * 3. Libraries installieren: M5StickC, PubSubClient
 * 4. WLAN-Daten unten anpassen falls nötig
 * 5. Hochladen!
 * 
 * Autor: SIDEKICK Team
 * Datum: Dezember 2025
 */

#include <M5StickC.h>
#include <WiFi.h>
#include <PubSubClient.h>

// =============================================================================
// KONFIGURATION - Bei Bedarf anpassen!
// =============================================================================

// WLAN Zugangsdaten (SIDEKICK Hotspot)
const char* WIFI_SSID = "SIDEKICK-RPI";      // Kann auch SIDEKICK-RPI-2 etc. sein
const char* WIFI_PASSWORD = "sidekick";

// MQTT Broker (Raspberry Pi im Hotspot-Modus)
const char* MQTT_SERVER = "10.42.0.1";
const int MQTT_PORT = 1883;

// Button-Nummer (keine Begrenzung, cyclet 1-99 der Einfachheit halber)
int currentButtonNumber = 1;

// Geräte-ID (für mehrere M5StickC)
const char* DEVICE_ID = "m5stick-1";

// =============================================================================
// Globale Variablen
// =============================================================================

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

int currentButtonNumber = 1;  // Aktuelle Button-Nummer
bool lastButtonAState = false;
unsigned long buttonBPressTime = 0;
bool buttonBLongPress = false;

unsigned long lastReconnectAttempt = 0;

// =============================================================================
// Funktions-Deklarationen
// =============================================================================

void connectWiFi();
bool connectMQTT();
void showStatus(const char* msg, uint16_t color);
void flashScreen(uint16_t color);
void updateDisplay();
void publishButtonState(const char* state);

// =============================================================================
// Setup
// =============================================================================

void setup() {
    M5.begin();
    Serial.begin(115200);
    
    Serial.println("\n=== SIDEKICK M5StickC ===");
    Serial.println("Button A: Event senden");
    Serial.println("Button B kurz: Nummer +");
    Serial.println("Button B lang: Nummer -");
    
    // Display Setup
    M5.Lcd.setRotation(1);  // Landscape
    M5.Lcd.fillScreen(TFT_BLACK);
    M5.Lcd.setTextColor(TFT_WHITE);
    M5.Lcd.setTextSize(2);
    M5.Lcd.setCursor(5, 5);
    M5.Lcd.println("SIDEKICK");
    M5.Lcd.setTextSize(1);
    M5.Lcd.println("Verbinde...");
    
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
    
    // ========== Button A: Event senden ==========
    if (M5.BtnA.wasPressed()) {
        Serial.printf("Button %d PRESSED\n", currentButtonNumber);
        publishButtonState("pressed");
        lastButtonAState = true;
        flashScreen(TFT_GREEN);
        showStatus("PRESSED!", TFT_GREEN);
    }
    
    if (M5.BtnA.wasReleased()) {
        if (lastButtonAState) {
            Serial.printf("Button %d RELEASED\n", currentButtonNumber);
            publishButtonState("released");
            lastButtonAState = false;
            updateDisplay();
        }
    }
    
    // ========== Button B: Nummer wechseln ==========
    if (M5.BtnB.wasPressed()) {
        buttonBPressTime = millis();
        buttonBLongPress = false;
    }
    
    // Long press detection (after 500ms)
    if (M5.BtnB.isPressed() && !buttonBLongPress) {
        if (millis() - buttonBPressTime > 500) {
            buttonBLongPress = true;
            // Nummer runter
            currentButtonNumber--;
            if (currentButtonNumber < 1) currentButtonNumber = 99;
            Serial.printf("Button-Nummer: %d (lang)\n", currentButtonNumber);
            updateDisplay();
        }
    }
    
    if (M5.BtnB.wasReleased()) {
        if (!buttonBLongPress) {
            // Kurzer Druck: Nummer hoch
            currentButtonNumber++;
            if (currentButtonNumber > 99) currentButtonNumber = 1;
            Serial.printf("Button-Nummer: %d (kurz)\n", currentButtonNumber);
            updateDisplay();
        }
    }
    
    delay(10);
}

// =============================================================================
// WiFi Verbindung
// =============================================================================

void connectWiFi() {
    Serial.print("Verbinde zu WiFi: ");
    Serial.println(WIFI_SSID);
    
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
        
        // LED blinken
        M5.Lcd.fillCircle(150, 40, 5, TFT_YELLOW);
        delay(100);
        M5.Lcd.fillCircle(150, 40, 5, TFT_BLACK);
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi verbunden!");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        showStatus("WiFi OK!", TFT_GREEN);
    } else {
        Serial.println("\nWiFi Fehler!");
        showStatus("WiFi Fehler!", TFT_RED);
    }
}

// =============================================================================
// MQTT Verbindung
// =============================================================================

bool connectMQTT() {
    Serial.println("Verbinde zu MQTT...");
    
    String clientId = String(DEVICE_ID) + "-" + String(random(0xffff), HEX);
    
    if (mqttClient.connect(clientId.c_str())) {
        Serial.println("MQTT verbunden!");
        mqttClient.publish("sidekick/m5stick/status", "connected");
        updateDisplay();
        return true;
    } else {
        Serial.printf("MQTT Fehler: %d\n", mqttClient.state());
        showStatus("MQTT Fehler!", TFT_RED);
        return false;
    }
}

// =============================================================================
// Button-Event publizieren
// =============================================================================

void publishButtonState(const char* state) {
    if (!mqttClient.connected()) {
        Serial.println("MQTT nicht verbunden!");
        flashScreen(TFT_RED);
        return;
    }
    
    char topic[64];
    snprintf(topic, sizeof(topic), "sidekick/button/%d/state", currentButtonNumber);
    
    mqttClient.publish(topic, state);
    Serial.printf("MQTT: %s → %s\n", topic, state);
}

// =============================================================================
// Display Funktionen
// =============================================================================

void updateDisplay() {
    M5.Lcd.fillScreen(TFT_BLACK);
    
    // Titel
    M5.Lcd.setTextSize(1);
    M5.Lcd.setTextColor(TFT_WHITE);
    M5.Lcd.setCursor(5, 5);
    M5.Lcd.print("SIDEKICK");
    
    // Verbindungsstatus
    if (WiFi.status() == WL_CONNECTED && mqttClient.connected()) {
        M5.Lcd.fillCircle(150, 8, 5, TFT_GREEN);
    } else {
        M5.Lcd.fillCircle(150, 8, 5, TFT_RED);
    }
    
    // Große Button-Nummer
    M5.Lcd.setTextSize(5);
    M5.Lcd.setTextColor(TFT_YELLOW);
    M5.Lcd.setCursor(65, 25);
    M5.Lcd.printf("%d", currentButtonNumber);
    
    // Info unten
    M5.Lcd.setTextSize(1);
    M5.Lcd.setTextColor(TFT_LIGHTGREY);
    M5.Lcd.setCursor(5, 70);
    M5.Lcd.printf("Topic: button/%d/state", currentButtonNumber);
}

void showStatus(const char* msg, uint16_t color) {
    M5.Lcd.setTextSize(1);
    M5.Lcd.setTextColor(color);
    M5.Lcd.setCursor(5, 70);
    M5.Lcd.fillRect(0, 65, 160, 15, TFT_BLACK);
    M5.Lcd.print(msg);
}

void flashScreen(uint16_t color) {
    M5.Lcd.fillScreen(color);
    delay(50);
}
