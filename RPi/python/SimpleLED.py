#!/usr/bin/env python3
# rpi_ws281x library strandtest example
# Author: Tony DiCola (tony@tonydicola.com)
#
# Direct port of the Arduino NeoPixel library strandtest example.  Showcases
# various animations on a strip of NeoPixels.

import time
import neopixel
import argparse

# LED strip configuration:
LED_COUNT      = 7     # Number of LED pixels.
LED_PIN        = 12      # GPIO pin connected to the pixels (18 uses PWM!).
#LED_PIN        = 10      # GPIO pin connected to the pixels (10 uses SPI /dev/spidev0.0).
LED_FREQ_HZ    = 800000  # LED signal frequency in hertz (usually 800khz)
LED_DMA        = 10      # DMA channel to use for generating signal (try 10)
LED_BRIGHTNESS = 255     # Set to 0 for darkest and 255 for brightest
LED_INVERT     = False   # True to invert the signal (when using NPN transistor level shift)
LED_CHANNEL    = 0       # set to '1' for GPIOs 13, 19, 41, 45 or 53



def ChangeColor(strip, MODE, BOX):
    LED_COUNT_START      = LED_COUNT * BOX
    LED_COUNT_END        = LED_COUNT_START + LED_COUNT

    if MODE == 0:
        print("CLEAR MODE")
        for i in range(LED_COUNT_START, LED_COUNT_END):
            strip.setPixelColor(i, neopixel.Color(0,0,0))
        strip.show()
    if MODE == 1:
        print("RED MODE")
        for i in range(LED_COUNT_START, LED_COUNT_END):
            strip.setPixelColor(i, neopixel.Color(255,0,0))
        strip.show()

    if MODE == 2:
        print("GREEN MODE")
        for i in range(LED_COUNT_START, LED_COUNT_END):
            strip.setPixelColor(i, neopixel.Color(0,255,0))
        strip.show()

    if MODE == 3:
        print("YELLOW MODE")
        for i in range(LED_COUNT_START, LED_COUNT_END):
            strip.setPixelColor(i, neopixel.Color(255,255,0))
        strip.show()

#if __name__ == "__main__":
 #   strip = Adafruit_NeoPixel(24, 18, LED_FREQ_HZ, LED_DMA, LED_INVERT, LED_BRIGHTNESS, LED_CHANNEL)
  #  strip.begin()
   # ChangeColor(strip,1,2)