import threading
import time

exitFlag = 0


class HandDetection(threading.Thread):

    def __init__(self, threadID, name, counter, scratchSocket):
        threading.Thread.__init__(self)
        self.threadID = threadID
        self.name = name
        self.counter = counter
        self.scratchSocket = scratchSocket

    def handDetection(self, ultrasonicDevice):
        handDetected = False
        notDetectedCounter = 0
        while True:
            distance = ultrasonicDevice.measure()
            print(distance)
            if distance >= 18.0: # and distance >= -0.5:
                if handDetected:
                    notDetectedCounter += 1
                    if notDetectedCounter == 3:
                        self.scratchSocket.sendScratchCommand("hand")
                        handDetected = False
                        print("Hand rausgenommen.")
                        notDetectedCounter = 0
                else:                    
                    print("Keine Hand erkannt.")
                    time.sleep(0.5)
            else:
                handDetected = True
                time.sleep(0.5)
                notDetectedCounter = 0

    def run(self):
        print("Starting " + self.name)
        self.handDetection()
        print("Exiting " + self.name)
