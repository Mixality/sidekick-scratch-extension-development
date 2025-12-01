#! /usr/bin/python2

import time
import sys

EMULATE_HX711=False

referenceUnit = 5
N = 0

if not EMULATE_HX711:
    import RPi.GPIO as GPIO
    from hx711 import HX711
else:
    from emulated_hx711 import HX711

from pynput.keyboard import Key, Controller
hx = HX711(5, 6)

class ScaleClass:

    def __init__(self):
        self.longTermPlus = 0
        self.longTermPlus = 0
        self.CaliValue = 0
        self.keyboard = Controller()
    
    def weightTest(self):
        print(hx.get_units())
    
    def cleanAndExit(self):
        print("Cleaning...")

        if not EMULATE_HX711:
            GPIO.cleanup()

        print("Bye!")
        sys.exit()

    def setup(self):
        self.longTermPlus = 0
        self.longTermMinus = 0
        hx.set_reading_format("MSB", "MSB")
        hx.set_reference_unit(referenceUnit)
        hx.reset()
        hx.tare()
        print("Add weight for calibration")
        ZeroWeight = hx.get_weight(5)
        hx.power_down()
        hx.power_up()
        CalibrationValue = 0
        while True:     
            print("Waiting..." + str(hx.get_weight(5)))
            if hx.get_weight(5) >= (ZeroWeight + 200) or hx.get_weight(5) <= (ZeroWeight - 200):
                print("Weight detected. Calibration in progress...")
                time.sleep(3)
                CalibrationValue = hx.get_weight(5)
                hx.power_down()
                hx.power_up()
                time.sleep(1)
                CalibrationValue = CalibrationValue + hx.get_weight(5)
                hx.power_down()
                hx.power_up()
                time.sleep(1)
                CalibrationValue = CalibrationValue + hx.get_weight(5)
                hx.power_down()
                hx.power_up()
                CalibrationValue = CalibrationValue / 3
                self.CaliValue = CalibrationValue
                print("Calibration done"+str(CalibrationValue))
                break;



    # to use both channels, you'll need to tare them both
    #hx.tare_A()
    #hx.tare_B()

    def checkWeight(self):
        global N
        try:
            print("START")
            checkVal = hx.get_weight(5)
            if checkVal <= ((self.CaliValue * (N + 1 ))+ 100):
                self.longTermPlus = self.longTermPlus + 1
                if self.longTermPlus >= 1:
                    N = N + 1
                    print("Anzahl Schrauben: "+ str(N))
                    self.longTermPlus = 0
                    self.keyboard.press('o')
            elif checkVal >= ((self.CaliValue * (N - 1)) - 100) and N>=1:
                self.longTermMinus = self.longTermMinus + 1
                if self.longTermMinus >= 3:
                    N = N - 1
                    print("Anzahl Schrauben: "+ str(N))
                    self.longTermMinus = 1
                    self.keyboard.press('p')
            else:
                self.longTermPlus = 0
                self.longTermMinus = 0
            hx.power_down()
            hx.power_up()
        except (KeyboardInterrupt, SystemExit):
            cleanAndExit()

if __name__ == '__main__':
    B = ScaleClass()
    B.setup()
    while True:
        B.checkWeight()
        

