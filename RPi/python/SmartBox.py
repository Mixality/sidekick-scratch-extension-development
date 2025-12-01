from __future__ import print_function
import time
import RPi.GPIO as GPIO
import SimpleLED
import neopixel
import os
from pynput.keyboard import Key, Controller
import paho.mqtt.client as mqtt

TEMPERATURE = 20
SPEED_OF_SOUND = 33100 + (0.6 * TEMPERATURE)
AVERAGE_DELTA = 6
GPIO_US_TRIGGER = 25

console_timer = 0

# MQTT Konfiguration
MQTT_BROKER = "localhost"  # Ändere dies zur IP/Hostname deines MQTT-Brokers
MQTT_PORT = 1883
MQTT_TOPIC_BASE = "sidekick/box"  # Topic-Format: sidekick/box/{box_nr}/hand_detected
MQTT_ENABLED = True  # Setze auf False, um MQTT zu deaktivieren

# Globaler MQTT-Client
mqtt_client = None


def init_mqtt():
    """Initialisiert die MQTT-Verbindung."""
    global mqtt_client
    if not MQTT_ENABLED:
        print("MQTT ist deaktiviert.")
        return None
    
    try:
        mqtt_client = mqtt.Client()
        mqtt_client.on_connect = on_mqtt_connect
        mqtt_client.on_disconnect = on_mqtt_disconnect
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        mqtt_client.loop_start()  # Startet Background-Thread für MQTT
        print(f"MQTT-Verbindung zu {MQTT_BROKER}:{MQTT_PORT} wird hergestellt...")
        return mqtt_client
    except Exception as e:
        print(f"MQTT-Verbindung fehlgeschlagen: {e}")
        print("Fahre ohne MQTT fort...")
        return None


def on_mqtt_connect(client, userdata, flags, rc):
    """Callback bei erfolgreicher MQTT-Verbindung."""
    if rc == 0:
        print("MQTT-Verbindung erfolgreich hergestellt!")
    else:
        print(f"MQTT-Verbindung fehlgeschlagen mit Code: {rc}")


def on_mqtt_disconnect(client, userdata, rc):
    """Callback bei MQTT-Verbindungsverlust."""
    print("MQTT-Verbindung getrennt.")


def publish_hand_detected(box_nr):
    """Sendet eine MQTT-Nachricht, wenn eine Hand erkannt wurde."""
    global mqtt_client
    if mqtt_client is not None and MQTT_ENABLED:
        topic = f"{MQTT_TOPIC_BASE}/{box_nr}/hand_detected"
        try:
            mqtt_client.publish(topic, "1")
            print(f"MQTT: Hand erkannt an Box {box_nr} -> Topic: {topic}")
        except Exception as e:
            print(f"MQTT-Publish fehlgeschlagen: {e}")

class SmartBox:

    def __init__(self, GPIO_US_ECHO, box_nr, GPIO_LED_MESSAGEPIN):
        self.GPIO_LED_MESSAGEPIN = GPIO_LED_MESSAGEPIN
        self.GPIO_US_ECHO = GPIO_US_ECHO
        self.box_nr = box_nr
        self.keyboard = Controller()
        self.startTime = 0
        self.endTime = 0
        self.elapsed = 0
        self.distance = 0
        self.StartFlag = False
        self.handDetected = False
        self.notDetectedCounter = 0
        self.detectedCounter = 0
        self.valueChanged = False
        self.init_GPIO()
        self.inactive = False
        print("Initalisiere SmartBox " + str(self.box_nr) + "...")
        self.averageUltra = self.measure_average()
        print("Initialwert von Box " + str(self.box_nr) + ": " + str(self.averageUltra) + "\n")

    # Sets ultrasonic trigger to true for 10us.
    @staticmethod
    def trigger_ultrasonic():
        GPIO.output(GPIO_US_TRIGGER, True)
        # Wait 10us
        time.sleep(0.00001)
        GPIO.output(GPIO_US_TRIGGER, False)

    def time_ultrasonic(self):

        if GPIO.input(self.GPIO_US_ECHO) == 1 and self.StartFlag == False:
            self.startTime = time.time()
            self.StartFlag = True

        if GPIO.input(self.GPIO_US_ECHO) == 0 and self.StartFlag == True:
            self.endTime = time.time()
            self.StartFlag = False

    def reset_ultrasonic(self):
        self.startTime = 0
        self.endTime = 0
        self.StartFlag = 0

    def calculate_distance(self):
        self.elapsed = self.endTime - self.startTime
        self.distance = (self.elapsed * SPEED_OF_SOUND) / 2

    def measure_ultrasonic(self):
        currentTime = time.time()
        elapsedTime = 0

        while elapsedTime <= 0.05:
            self.time_ultrasonic()
            elapsedTime = time.time() - currentTime
        # print("calculate distance")
        self.calculate_distance()

    def measure_average(self):
        # This function takes 3 measurements and
        # returns the average.
        self.trigger_ultrasonic()
        self.measure_ultrasonic()
        distance1 = self.distance
        time.sleep(0.1)

        self.trigger_ultrasonic()
        self.measure_ultrasonic()
        distance2 = self.distance
        time.sleep(0.1)

        self.trigger_ultrasonic()
        self.measure_ultrasonic()
        distance3 = self.distance
        time.sleep(0.1)

        distance = distance1 + distance2 + distance3
        distance = distance / 3
        if distance == 0.0:
            self.inactive = True
        return distance

    # Initializes GPIO pins of this smartbox.
    def init_GPIO(self):
        GPIO.setmode(GPIO.BCM)

        GPIO.setup(23, GPIO.IN)
        # print("Ultrasonic Measurement")

        # Set pins as output and input
        GPIO.setup(GPIO_US_TRIGGER, GPIO.OUT)  # Trigger
        GPIO.setup(self.GPIO_US_ECHO, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)  # Echo
        GPIO.setup(self.GPIO_LED_MESSAGEPIN, GPIO.IN)
        # Set trigger to False (Low)
        GPIO.output(GPIO_US_TRIGGER, False)
        # Allow module to settle
        time.sleep(0.5)

    # Main routine of the smartbox.
    def LED_control(self, strip):
        if GPIO.input(self.GPIO_LED_MESSAGEPIN) == True and self.valueChanged == False:
            SimpleLED.ChangeColor(strip, 1, self.box_nr - 1)
            self.valueChanged = True
        elif GPIO.input(self.GPIO_LED_MESSAGEPIN) == False and self.valueChanged == True:
            SimpleLED.ChangeColor(strip, 2, self.box_nr - 1)
            self.valueChanged = False
        # ~ #Nur Grün
        # ~ while True:
        # ~ if GPIO.input(self.GPIO_LED_MESSAGEPIN) == True and valueChanged == False:
        # ~ SimpleLED.ChangeColor(strip, 2,self.box_nr)
        # ~ valueChanged = True
        # ~ elif GPIO.input(self.GPIO_LED_MESSAGEPIN) == False and valueChanged == True:
        # ~ SimpleLED.ChangeColor(strip, 0, self.box_nr)
        # ~ valueChanged = False

    # ~ #       while True:
    # ~ #           if GPIO.input(self.GPIO_LED_MESSAGEPIN) == True and valueChanged == False and GPIO.input(23):
    # ~ #               SimpleLED.ChangeColor(strip, 2,self.box_nr)
    # ~ #               valueChanged = True
    # ~ #
    # ~ #           elif GPIO.input(self.GPIO_LED_MESSAGEPIN) == False and valueChanged == True and GPIO.input(23):
    # ~ #               SimpleLED.ChangeColor(strip, 0, self.box_nr)
    # ~ #               valueChanged = False
    # ~ #
    # ~ #           if GPIO.input(self.GPIO_LED_MESSAGEPIN) == True and valueChanged == False:
    # ~ #              SimpleLED.ChangeColor(strip, 1,self.box_nr)
    # ~ #               valueChanged = True
    # ~ #
    # ~ #           elif GPIO.input(self.GPIO_LED_MESSAGEPIN) == False and valueChanged == True:
    # ~ #               SimpleLED.ChangeColor(strip, 0, self.box_nr)
    # ~ #               valueChanged = False

    # ~ handDetected, notDetectedCounter, detectedCounter = self.handDetection(handDetected, notDetectedCounter, detectedCounter)

    def handDetection(self):
        # print(str(self.GPIO_US_MESSAGEPIN) + " " + str(distance))

        # If the distance value is between the spceified bounds.
        if self.distance > 15:
        #(self.averageUltra - AVERAGE_DELTA) and self.distance <= (
         #       self.averageUltra + AVERAGE_DELTA):
            # Reset the detected Counter.
            self.detectedCounter = 0
            # If a hand was detected in the last iteration of this function.
            # If this happened three times in a row, we are sure the hand is not in the box anymore
            # Therfore the message pin is signaled.
            if self.handDetected:
                self.notDetectedCounter += 1
                if self.notDetectedCounter ==15:
                    # Keyboard-Input (Original-Methode)
                    self.keyboard.press(str(self.box_nr))
                    # GPIO.output(self.GPIO_US_MESSAGEPIN, GPIO.HIGH)
                    # time.sleep(0.1)
                    # GPIO.output(self.GPIO_US_MESSAGEPIN, GPIO.LOW)
                    self.keyboard.release(str(self.box_nr))
                    
                    # MQTT-Nachricht senden
                    publish_hand_detected(self.box_nr)
                    
                    self.handDetected = False
                    print("Hand rausgenommen.")
                    self.notDetectedCounter = 0
            # else:
            # print("Keine Hand erkannt.")
            # print("Keine Hand erkannt.")
            # time.sleep(0.5)
        else:
            self.detectedCounter += 1
            if self.detectedCounter == 3:
                self.handDetected = True
                # time.sleep(0.5)
            self.notDetectedCounter = 0


def initSmartBoxes():
    
    smartbox_1 = SmartBox(18, 1, 7)
    smartbox_2 = SmartBox(23, 2, 8)
    smartbox_3 = SmartBox(24, 3, 14)
    smartbox_4 = SmartBox(5, 4, 16)
    smartbox_5 = SmartBox(11, 5, 20)
    smartbox_6 = SmartBox(9, 6, 21)
    smartbox_7 = SmartBox(6, 7, 15)
    smartbox_8 = SmartBox(13, 8, 2)
    smartbox_9 = SmartBox(19, 9, 3)

    smartboxes = []
    smartboxes.extend(
        [smartbox_1, smartbox_2, smartbox_3, smartbox_4, smartbox_5, smartbox_6, smartbox_7, smartbox_8, smartbox_9])

    smartboxes = checkSmartBoxes(smartboxes)
    return smartboxes


def checkSmartBoxes(smartboxes):
    filteredSmartboxes = list(smartboxes)
    for smartbox in smartboxes:
        if smartbox.inactive:
            filteredSmartboxes.remove(smartbox)

    return filteredSmartboxes


def runBoxes():
    GPIO.cleanup()
    
    # MQTT initialisieren
    init_mqtt()
    
    # Echo, BoxNr, LED_Message
    smartboxes = initSmartBoxes()
    strip = neopixel.Adafruit_NeoPixel(70, 12, SimpleLED.LED_FREQ_HZ, SimpleLED.LED_DMA, SimpleLED.LED_INVERT,
                              SimpleLED.LED_BRIGHTNESS, SimpleLED.LED_CHANNEL)
    strip.begin()
    endtime = time.time() + 1

    while 1:
        try:

            start = time.time()
            elapsed = 0
            statusString = ""
            SmartBox.trigger_ultrasonic()
            while (elapsed <= 0.05):
                for smartbox in smartboxes:
                    smartbox.time_ultrasonic()
                elapsed = time.time() - start
                
            for smartbox in smartboxes:
                smartbox.calculate_distance()
                smartbox.handDetection()
                smartbox.LED_control(strip)
                statusString += "SmartBox " + str(smartbox.box_nr) + " Messwert: " + str(round(smartbox.distance,2)) + "\n"
            
            
            if start >= endtime:
                os.system("clear")
                print(statusString)
                endtime = time.time() + 1

        except KeyboardInterrupt:
            # MQTT sauber beenden
            if mqtt_client is not None:
                mqtt_client.loop_stop()
                mqtt_client.disconnect()
                print("MQTT-Verbindung beendet.")
            GPIO.cleanup()
