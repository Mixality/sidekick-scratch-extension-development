const BlockType = require('../../extension-support/block-type');
const ArgumentType = require('../../extension-support/argument-type');
// const TargetType = require('../../extension-support/target-type');

const MQTT_BROKERS = {
    hotspot: {
        id: 'hotspot',
        peripheralId: 'hotspot',
        key: 'hotspot',
        name: 'SIDEKICK RPi Hotspot',
        rssi: 1,

        brokerAddress: 'ws://10.42.0.1:9001'
    },
    devHome: {
        id: 'devHome',
        peripheralId: 'devHome',
        key: 'devHome',
        name: 'Home Network (Development)',
        rssi: 2,

        brokerAddress: 'ws://192.168.178.117:9001'
    }
    // ,
    // mosquitto: {
    //     id: 'mosquitto',
    //     peripheralId: 'mosquitto',
    //     key: 'mosquitto',
    //     name: 'Mosquitto',
    //     rssi: 2,

    //     brokerAddress: 'wss://test.mosquitto.org:8081'
    // }
    // ,
    // eclipse: {
    //     id: 'eclipse',
    //     peripheralId: 'eclipse',
    //     key: 'eclipse',
    //     name: 'Eclipse Projects',
    //     rssi: 3,

    //     brokerAddress: 'wss://mqtt.eclipseprojects.io:443/mqtt'
    // }
    // ,
    // hivemq: {
    //     id: 'hivemq',
    //     peripheralId: 'hivemq',
    //     key: 'hivemq',
    //     name: 'HiveMQ',
    //     rssi: 4,

    //     brokerAddress: 'wss://broker.hivemq.com:8884/mqtt'
    // },
    // emqx: {
    //     id: 'emqx',
    //     peripheralId: 'emqx',
    //     key: 'emqx',
    //     name: 'EMQX',
    //     rssi: 5,

    //     brokerAddress: 'wss://broker.emqx.io:8084/mqtt'
    // }
};

class MqttConnection {
    constructor(runtime, extensionId) {
        this._isMqttConnected = false;
        this._running = false;

        this._runtime = runtime;
        this._runtime.on('PROJECT_START', this.projectStart.bind(this));
        this._runtime.on('PROJECT_STOP_ALL', this.projectStop.bind(this));

        this._extensionId = extensionId;

        this._runtime.registerPeripheralExtension(extensionId, this);

        this._scan();

        // Speichert für jedes Topic: { lastMessage: string, hasNewMessage: boolean }
        this._subscriptions = {};
    }

    projectStart() {
        this._running = true;
    }

    projectStop() {
        this._running = false;

        if (this._isMqttConnected) {
            console.log('[sidekick] mqtt unsubscribing');
            this._mqttClient.unsubscribe(Object.keys(this._subscriptions));
            this._subscriptions = {};
        }
    }

    scan() {
        setTimeout(() => {
            this._scan();
        }, 200);
    }

    _scan() {
        this._runtime.emit(this._runtime.constructor.PERIPHERAL_LIST_UPDATE, MQTT_BROKERS);
    }

    connect(id) {
        console.log('[sidekick] mqtt connect', id);

        if (typeof window.mqtt === 'undefined' || typeof window.mqtt.connect !== 'function') {
            console.error('[sidekick] MQTT library not loaded yet');
            return;
        }

        this._mqttClient = window.mqtt.connect(MQTT_BROKERS[id].brokerAddress);
        this._mqttClient.on('connect', () => {
            this._isMqttConnected = true;
            this._runtime.emit(this._runtime.constructor.PERIPHERAL_CONNECTED);
        });
        this._mqttClient.on('error', (err) => {
            this._isMqttConnected = false;
            console.log('[sidekick] mqtt error', err);
            this._runtime.emit(this._runtime.constructor.PERIPHERAL_REQUEST_ERROR, {
                message: `Connection error`,
                extensionId: this._extensionId
            });
        });
        this._mqttClient.on('message', (topic, message) => {
            console.log('[sidekick] message', topic, message.toString());
            if (this._running && topic in this._subscriptions) {
                this._subscriptions[topic].lastMessage = message.toString();
                this._subscriptions[topic].hasNewMessage = true;
            }
        });
    }

    connectToBroker(brokerAddress) {
        console.log('[sidekick] mqtt connect', brokerAddress);

        if (typeof window.mqtt === 'undefined' || typeof window.mqtt.connect !== 'function') {
            console.error('[sidekick] MQTT library not loaded yet');
            return;
        }

        this._mqttClient = window.mqtt.connect(brokerAddress);
        this._mqttClient.on('connect', () => {
            this._isMqttConnected = true;
            this._runtime.emit(this._runtime.constructor.PERIPHERAL_CONNECTED);
        });
        this._mqttClient.on('error', (err) => {
            this._isMqttConnected = false;
            console.log('[sidekick] mqtt error', err);
            this._runtime.emit(this._runtime.constructor.PERIPHERAL_REQUEST_ERROR, {
                message: `Connection error`,
                extensionId: this._extensionId
            });
        });
        this._mqttClient.on('message', (topic, message) => {
            console.log('[sidekick] message', topic, message.toString());
            if (this._running && topic in this._subscriptions) {
                this._subscriptions[topic].lastMessage = message.toString();
                this._subscriptions[topic].hasNewMessage = true;
            }
        });
    }

    disconnect() {
        // console.log('[sidekick] mqtt disconnect', id);

        var force = true;
        this._mqttClient.end(force);
        delete this._mqttClient;

        this._isMqttConnected = false;
        this._subscriptions = {};

        this._runtime.emit(this._runtime.constructor.PERIPHERAL_DISCONNECTED);
    }

    isConnected() {
        return this._isMqttConnected;
    }

    mqttPublish(topic, messageString) {
        if (this._isMqttConnected && this._running) {
            this._mqttClient.publish(topic, messageString.toString());
        }
    }

    mqttSubscribe(topic) {
        if (!this._isMqttConnected || !this._running) {
            return false;
        }
        if (!(topic in this._subscriptions)) {
            console.log('[sidekick] mqtt subscribing to', topic);
            this._subscriptions[topic] = { lastMessage: '', hasNewMessage: false };
            this._mqttClient.subscribe(topic, (err) => {
                if (err) {
                    console.log('[sidekick] mqtt subscription error', err);
                    delete this._subscriptions[topic];
                }
            });
        }
        // Für HAT-Blocks: true wenn neue Nachricht, dann Flag zurücksetzen (edge-triggered)
        if (this._subscriptions[topic].hasNewMessage) {
            this._subscriptions[topic].hasNewMessage = false;
            return true;
        }
        return false;
    }

    mqttMessage(topic) {
        if (this._isMqttConnected &&
            this._running &&
            this._subscriptions[topic]) {
            // Gibt die letzte Nachricht zurück OHNE sie zu löschen
            return this._subscriptions[topic].lastMessage;
        }
        return '';
    }

    // Auto-subscribe zu einem Topic und gibt die letzte Nachricht zurück
    mqttGetLastMessage(topic) {
        this.mqttSubscribe(topic);  // Stellt sicher dass wir subscribed sind
        if (this._subscriptions[topic]) {
            return this._subscriptions[topic].lastMessage;
        }
        return '';
    }

    // Für HAT-Blöcke die auf bestimmte Werte reagieren sollen:
    // Gibt true zurück wenn neue Nachricht da ist UND der Inhalt matched.
    // Konsumiert die Nachricht NUR wenn der Wert passt!
    mqttSubscribeForValue(topic, expectedValue) {
        if (!this._isMqttConnected || !this._running) {
            return false;
        }
        if (!(topic in this._subscriptions)) {
            console.log('[sidekick] mqtt subscribing to', topic);
            this._subscriptions[topic] = { lastMessage: '', hasNewMessage: false };
            this._mqttClient.subscribe(topic, (err) => {
                if (err) {
                    console.log('[sidekick] mqtt subscription error', err);
                    delete this._subscriptions[topic];
                }
            });
        }
        // Nur wenn neue Nachricht UND der Wert passt, konsumieren wir die Flag
        if (this._subscriptions[topic].hasNewMessage && 
            this._subscriptions[topic].lastMessage === expectedValue) {
            this._subscriptions[topic].hasNewMessage = false;
            return true;
        }
        return false;
    }
}

class Scratch3SidekickBlocks {

    // constructor(runtime) {
    //     // put any setup for the extension here
    // }

    constructor(runtime) {
        this._runtime = runtime;

        this._libraryReady = false;
        this._loadMQTT();
    }

    /**
     * Returns the metadata about the extension.
     */
    getInfo() {
        return {
            // unique ID for the extension
            id: 'sidekick',

            // name that will be displayed in the Scratch UI
            name: 'SIDEKICK Extension',

            // colours to use for the extension blocks
            // colour for the blocks
            color1: '#660066',
            // colour for the menus in the blocks
            color2: '#ffffff',
            // border for blocks and parameter gaps
            color3: '#660066',

            showStatusButton: true,


            // icons to display
            // blockIconURI: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAAAAACyOJm3AAAAFklEQVQYV2P4DwMMEMgAI/+DEUIMBgAEWB7i7uidhAAAAABJRU5ErkJggg==',
            // menuIconURI: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAAAAACyOJm3AAAAFklEQVQYV2P4DwMMEMgAI/+DEUIMBgAEWB7i7uidhAAAAABJRU5ErkJggg==',
            menuIconURI: 'data:image/png;base64,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',

            // Scratch blocks
            blocks: [
                {
                    opcode: 'connection',
                    text: 'connect to [BROKER]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        BROKER: {
                            type: ArgumentType.STRING,
                            // defaultValue: 'wss://test.mosquitto.org:8081'
                            // defaultValue: 'ws://192.168.178.116:9001'
                            defaultValue: 'ws://10.42.0.1:9001'
                        }
                    }
                },
                '---',
                // ========== Hand-Erkennung (SmartBox) ==========
                {
                    opcode: 'whenHandDetected',
                    text: 'Wenn Hand erkannt an Box [BOX]',
                    blockType: BlockType.HAT,
                    arguments: {
                        BOX: {
                            type: ArgumentType.STRING,
                            menu: 'boxNumber',
                            defaultValue: '1'
                        }
                    }
                },
                {
                    opcode: 'isHandDetected',
                    text: 'Hand erkannt an Box [BOX]?',
                    blockType: BlockType.BOOLEAN,
                    arguments: {
                        BOX: {
                            type: ArgumentType.STRING,
                            menu: 'boxNumber',
                            defaultValue: '1'
                        }
                    }
                },
                '---',
                // ========== LED Steuerung ==========
                {
                    opcode: 'setLedColor',
                    text: 'Setze LED von Box [BOX] auf Farbe [COLOR]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        BOX: {
                            type: ArgumentType.STRING,
                            menu: 'boxNumberWithAll',
                            defaultValue: '1'
                        },
                        COLOR: {
                            type: ArgumentType.COLOR,
                            defaultValue: '#00ff00'
                        }
                    }
                },
                {
                    opcode: 'setLedColorPreset',
                    text: 'Setze LED von Box [BOX] auf [COLOR]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        BOX: {
                            type: ArgumentType.STRING,
                            menu: 'boxNumberWithAll',
                            defaultValue: '1'
                        },
                        COLOR: {
                            type: ArgumentType.STRING,
                            menu: 'colorMenu',
                            defaultValue: 'green'
                        }
                    }
                },
                {
                    opcode: 'setLedOff',
                    text: 'Schalte LED von Box [BOX] aus',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        BOX: {
                            type: ArgumentType.STRING,
                            menu: 'boxNumberWithAll',
                            defaultValue: '1'
                        }
                    }
                },
                '---',
                // ========== Button Blöcke ==========
                {
                    opcode: 'whenButtonAction',
                    text: 'Wenn Button [BUTTON] [ACTION] wird',
                    blockType: BlockType.HAT,
                    arguments: {
                        BUTTON: {
                            type: ArgumentType.STRING,
                            menu: 'buttonNumber',
                            defaultValue: '1'
                        },
                        ACTION: {
                            type: ArgumentType.STRING,
                            menu: 'buttonAction',
                            defaultValue: 'pressed'
                        }
                    }
                },
                {
                    opcode: 'isButtonState',
                    text: 'Button [BUTTON] [ACTION]?',
                    blockType: BlockType.BOOLEAN,
                    arguments: {
                        BUTTON: {
                            type: ArgumentType.STRING,
                            menu: 'buttonNumber',
                            defaultValue: '1'
                        },
                        ACTION: {
                            type: ArgumentType.STRING,
                            menu: 'buttonAction',
                            defaultValue: 'pressed'
                        }
                    }
                },
                '---',
                // ========== Allgemeine MQTT Blöcke ==========
                {
                    opcode: 'publish',
                    text: 'publish [MESSAGE] to [TOPIC]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        TOPIC: {
                            type: ArgumentType.STRING,
                            defaultValue: 'scratch/mqtt'
                        },
                        MESSAGE: {
                            type: ArgumentType.STRING,
                            defaultValue: 'hello world'
                        }
                    }
                },
                {
                    opcode: 'subscribe',
                    text: 'new message from [TOPIC]',
                    blockType: BlockType.HAT,
                    arguments: {
                        TOPIC: {
                            type: ArgumentType.STRING,
                            defaultValue: 'scratch/mqtt'
                        }
                    }
                },
                {
                    opcode: 'message',
                    text: 'message from [TOPIC]',
                    blockType: BlockType.REPORTER,
                    arguments: {
                        TOPIC: {
                            type: ArgumentType.STRING,
                            defaultValue: 'scratch/mqtt'
                        }
                    }
                }
            ],

            // [
            //     {
            //         // name of the function where the block code lives
            //         opcode: 'myFirstBlock',

            //         // type of block - choose from:
            //         //   BlockType.REPORTER - returns a value, like "direction"
            //         //   BlockType.BOOLEAN - same as REPORTER but returns a true/false value
            //         //   BlockType.COMMAND - a normal command block, like "move {} steps"
            //         //   BlockType.HAT - starts a stack if its value changes from false to true ("edge triggered")
            //         blockType: BlockType.REPORTER,

            //         // label to display on the block
            //         text: 'My first block [MY_NUMBER] and [MY_STRING]',

            //         // true if this block should end a stack
            //         terminal: false,

            //         // where this block should be available for code - choose from:
            //         //   TargetType.SPRITE - for code in sprites
            //         //   TargetType.STAGE  - for code on the stage / backdrop
            //         // remove one of these if this block doesn't apply to both
            //         filter: [TargetType.SPRITE, TargetType.STAGE],

            //         // arguments used in the block
            //         arguments: {
            //             MY_NUMBER: {
            //                 // default value before the user sets something
            //                 defaultValue: 123,

            //                 // type/shape of the parameter - choose from:
            //                 //     ArgumentType.ANGLE - numeric value with an angle picker
            //                 //     ArgumentType.BOOLEAN - true/false value
            //                 //     ArgumentType.COLOR - numeric value with a colour picker
            //                 //     ArgumentType.NUMBER - numeric value
            //                 //     ArgumentType.STRING - text value
            //                 //     ArgumentType.NOTE - midi music value with a piano picker
            //                 type: ArgumentType.NUMBER
            //             },
            //             MY_STRING: {
            //                 // default value before the user sets something
            //                 defaultValue: 'hello',

            //                 // type/shape of the parameter - choose from:
            //                 //     ArgumentType.ANGLE - numeric value with an angle picker
            //                 //     ArgumentType.BOOLEAN - true/false value
            //                 //     ArgumentType.COLOR - numeric value with a colour picker
            //                 //     ArgumentType.NUMBER - numeric value
            //                 //     ArgumentType.STRING - text value
            //                 //     ArgumentType.NOTE - midi music value with a piano picker
            //                 type: ArgumentType.STRING
            //             }
            //         }
            //     }
            // ]

            menus: {
                boxNumber: {
                    acceptReporters: false,
                    items: ['1', '2', '3', '4', '5', '6', '7', '8', '9']
                },
                boxNumberWithAll: {
                    acceptReporters: false,
                    items: [
                        { text: '1', value: '1' },
                        { text: '2', value: '2' },
                        { text: '3', value: '3' },
                        { text: '4', value: '4' },
                        { text: '5', value: '5' },
                        { text: '6', value: '6' },
                        { text: '7', value: '7' },
                        { text: '8', value: '8' },
                        { text: '9', value: '9' },
                        { text: 'alle', value: 'all' }
                    ]
                },
                buttonNumber: {
                    acceptReporters: false,
                    items: ['1', '2', '3', '4']
                },
                buttonAction: {
                    acceptReporters: false,
                    items: [
                        { text: 'gedrückt', value: 'pressed' },
                        { text: 'losgelassen', value: 'released' }
                    ]
                },
                colorMenu: {
                    acceptReporters: false,
                    items: [
                        { text: 'Rot', value: 'red' },
                        { text: 'Grün', value: 'green' },
                        { text: 'Blau', value: 'blue' },
                        { text: 'Gelb', value: 'yellow' },
                        { text: 'Weiß', value: 'white' },
                        { text: 'Orange', value: 'orange' },
                        { text: 'Lila', value: 'purple' },
                        { text: 'Cyan', value: 'cyan' },
                        { text: 'Pink', value: 'pink' }
                    ]
                }
            }
        };
    }


    /**
     * implementation of the block with the opcode that matches this name
     *  this will be called when the block is used
     */
    // myFirstBlock({ MY_NUMBER, MY_STRING }) {
    //     // example implementation to return a string
    //     return MY_STRING + ' : doubled would be ' + (MY_NUMBER * 2);
    // }
    connection({ BROKER }) {
        // if (!this._mqttConnection) {
        //     this._mqttConnection.connectToBroker(BROKER);
        // } else if (this._mqttConnection) {
        //     this._mqttConnection.disconnect();
        // }
        if (this._mqttConnection) {
            if (!this._mqttConnection.isConnected()) {
                this._mqttConnection.connectToBroker(BROKER);
            } else if (this._mqttConnection.isConnected()) {
                this._mqttConnection.disconnect();
            }
        }
    }

    // ========== Hand-Erkennung (SmartBox) ==========
    
    whenHandDetected({ BOX }) {
        if (this._mqttConnection) {
            const topic = `sidekick/box/${BOX}/hand`;
            // mqttSubscribe gibt true zurück wenn neue Nachricht da ist (edge-triggered)
            // Das reicht für den HAT-Block, da Python nur "detected" sendet
            return this._mqttConnection.mqttSubscribe(topic);
        }
        return false;
    }

    isHandDetected({ BOX }) {
        if (this._mqttConnection) {
            const topic = `sidekick/box/${BOX}/hand`;
            // Für den BOOLEAN-Block: Auto-subscribe und prüfen ob letzte Nachricht "detected" war
            const lastMessage = this._mqttConnection.mqttGetLastMessage(topic);
            return lastMessage === 'detected';
        }
        return false;
    }

    // ========== LED Steuerung ==========

    setLedColor({ BOX, COLOR }) {
        if (this._mqttConnection) {
            // COLOR kommt als Dezimalzahl vom Color-Picker (z.B. 16711680 für rot)
            // Konvertieren zu Hex-String #RRGGBB
            const hexColor = '#' + ('000000' + COLOR.toString(16)).slice(-6);
            const ledTopic = `sidekick/box/${BOX}/led`;
            this._mqttConnection.mqttPublish(ledTopic, hexColor);
            console.log('[sidekick] LED setzen:', ledTopic, hexColor);
        }
    }

    setLedColorPreset({ BOX, COLOR }) {
        if (this._mqttConnection) {
            const ledTopic = `sidekick/box/${BOX}/led`;
            this._mqttConnection.mqttPublish(ledTopic, COLOR);
            console.log('[sidekick] LED setzen (preset):', ledTopic, COLOR);
        }
    }

    setLedOff({ BOX }) {
        if (this._mqttConnection) {
            const ledTopic = `sidekick/box/${BOX}/led`;
            this._mqttConnection.mqttPublish(ledTopic, 'off');
            console.log('[sidekick] LED aus:', ledTopic);
        }
    }

    // ========== Button Steuerung ==========

    whenButtonAction({ BUTTON, ACTION }) {
        if (this._mqttConnection) {
            const topic = `sidekick/button/${BUTTON}/state`;
            // Prüfe ob neue Nachricht UND ob der Inhalt zur gewählten Aktion passt
            return this._mqttConnection.mqttSubscribeForValue(topic, ACTION);
        }
        return false;
    }

    isButtonState({ BUTTON, ACTION }) {
        if (this._mqttConnection) {
            const topic = `sidekick/button/${BUTTON}/state`;
            // Prüfe ob der aktuelle Zustand zur gewählten Aktion passt
            return this._mqttConnection.mqttGetLastMessage(topic) === ACTION;
        }
        return false;
    }

    // ========== Allgemeine MQTT Methoden ==========

    publish({ TOPIC, MESSAGE }) {
        if (this._mqttConnection) {
            this._mqttConnection.mqttPublish(TOPIC, MESSAGE);
        }
    }
    subscribe({ TOPIC }) {
        if (this._mqttConnection) {
            return this._mqttConnection.mqttSubscribe(TOPIC);
        }
    }
    message({ TOPIC }) {
        if (this._mqttConnection) {
            return this._mqttConnection.mqttMessage(TOPIC);
        }
    }

    _loadMQTT() {
        var id = 'mqtt-library-script';
        if (document.getElementById(id) || typeof window.mqtt !== 'undefined') {
            console.log('[sidekick] MQTT library already loaded');
            this._mqttLibraryLoaded();
            return;
        }

        console.log('[sidekick] loading MQTT library from CDN');

        var scriptObj = document.createElement('script');
        scriptObj.id = id;
        scriptObj.type = 'text/javascript';
        // Using a CDN version that's built for browsers
        // scriptObj.src = 'https://unpkg.com/mqtt@5.14.1/dist/mqtt.min.js';
        scriptObj.src = './sidekick-thirdparty-libraries/mqtt/mqtt.min.js';


        scriptObj.onreadystatechange = this._mqttLibraryLoaded.bind(this);
        scriptObj.onload = this._mqttLibraryLoaded.bind(this);
        scriptObj.onerror = (err) => {
            console.error('[sidekick] Failed to load MQTT library from CDN', err);
        };

        document.head.appendChild(scriptObj);
    }

    _mqttLibraryLoaded() {
        if (this._libraryReady) return;

        this._libraryReady = true;
        console.log('[sidekick] MQTT library loaded, creating connection');
        this._mqttConnection = new MqttConnection(this._runtime, 'sidekick');
    }
}

module.exports = Scratch3SidekickBlocks;
