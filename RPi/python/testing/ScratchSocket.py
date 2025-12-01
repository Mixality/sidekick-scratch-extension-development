import socket
import sys


class ScratchSocket:

    def __init__(self):
        self.PORT = 42001
        self.HOST = "localhost"
        self.scratchSock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.connected = False

    def connect(self):
        print("Connecting...")
        self.scratchSock.connect((self.HOST, self.PORT))
        print("Connected!")
        self.connected = True

    def sendScratchCommand(self, cmd):
        sendString = 'broadcast "{}"'.format(cmd)
        length = len(sendString)
        self.scratchSock.send(length.to_bytes(4, 'big'))
        self.scratchSock.send(bytes(sendString, 'UTF-8'))

    def closeSocket(self):
        print("Closing Socket...")
        self.scratchSock.close()
        print("Socket closed")
