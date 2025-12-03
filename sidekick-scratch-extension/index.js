const BlockType = require('../../extension-support/block-type');
const ArgumentType = require('../../extension-support/argument-type');
// const TargetType = require('../../extension-support/target-type');
const Cast = require('../../util/cast');

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

/**
 * VideoSkin - Eine echte Skin-Klasse die von BitmapSkin erbt.
 * Wird dynamisch erstellt wenn der Renderer verfügbar ist.
 */
let VideoSkinClass = null;
let _frameCounter = 0;

function getOrCreateVideoSkinClass(renderer) {
    if (VideoSkinClass) return VideoSkinClass;
    
    // Versuche BitmapSkin auf verschiedene Arten zu bekommen
    let BitmapSkin = null;
    
    // Methode 1: renderer.exports (alte Versionen)
    if (renderer.exports && renderer.exports.BitmapSkin) {
        BitmapSkin = renderer.exports.BitmapSkin;
        console.log('[sidekick] Found BitmapSkin via renderer.exports');
    }
    
    // Methode 2: Finde BitmapSkin durch eine existierende Skin im Renderer
    if (!BitmapSkin && renderer._allSkins) {
        for (const skin of renderer._allSkins) {
            if (skin && skin.constructor && skin.constructor.name === 'BitmapSkin') {
                BitmapSkin = skin.constructor;
                console.log('[sidekick] Found BitmapSkin via existing skin');
                break;
            }
        }
    }
    
    // Methode 3: Erstelle eine temporäre Skin um die Klasse zu bekommen
    if (!BitmapSkin) {
        try {
            const tempCanvas = document.createElement('canvas');
            tempCanvas.width = 1;
            tempCanvas.height = 1;
            const tempSkinId = renderer.createBitmapSkin(tempCanvas, 1);
            if (renderer._allSkins[tempSkinId]) {
                BitmapSkin = renderer._allSkins[tempSkinId].constructor;
                console.log('[sidekick] Found BitmapSkin via temp skin, constructor:', BitmapSkin.name);
            }
            renderer.destroySkin(tempSkinId);
        } catch (e) {
            console.error('[sidekick] Failed to create temp skin:', e);
        }
    }
    
    if (!BitmapSkin) {
        console.error('[sidekick] Could not find BitmapSkin class');
        return null;
    }
    
    console.log('[sidekick] BitmapSkin prototype methods:', Object.getOwnPropertyNames(BitmapSkin.prototype));
    
    VideoSkinClass = class VideoSkin extends BitmapSkin {
        constructor(id, renderer, videoName, videoSrc, runtime) {
            super(id, renderer);
            
            this._renderer = renderer;
            this._runtime = runtime;
            this._skinId = id;
            this.videoName = videoName;
            this.videoSrc = videoSrc;
            this.videoError = false;
            this._videoPlaying = false;
            this._lastTime = -1;
            this._frameCount = 0;
            
            // Canvas für Video-Frame-Capture
            this._canvas = document.createElement('canvas');
            this._ctx = this._canvas.getContext('2d', { willReadFrequently: true });
            
            this.readyPromise = new Promise((resolve) => {
                this.readyCallback = resolve;
            });
            
            this.videoElement = document.createElement('video');
            this.videoElement.crossOrigin = 'anonymous';
            this.videoElement.playsInline = true;
            this.videoElement.preload = 'auto';
            this.videoElement.muted = false;
            
            this.videoElement.onloadeddata = () => {
                console.log('[sidekick] Video loaded, dimensions:', this.videoElement.videoWidth, 'x', this.videoElement.videoHeight);
                // Canvas-Größe setzen
                this._canvas.width = this.videoElement.videoWidth;
                this._canvas.height = this.videoElement.videoHeight;
                this.readyCallback();
                this._captureFrame();
            };
            
            this.videoElement.onerror = (e) => {
                console.error('[sidekick] Video error:', videoName, e);
                this.videoError = true;
                this.readyCallback();
            };
            
            this.videoElement.src = videoSrc;
            this.videoElement.load();
        }
        
        _captureFrame() {
            if (this.videoError || !this.videoElement.videoWidth) {
                return;
            }
            
            // Video-Frame auf Canvas zeichnen
            this._ctx.drawImage(this.videoElement, 0, 0);
            
            // ImageData extrahieren - das ist was BitmapSkin am besten verarbeitet
            const imageData = this._ctx.getImageData(0, 0, this._canvas.width, this._canvas.height);
            
            // setBitmap mit ImageData aufrufen
            this.setBitmap(imageData, 1);
            
            this._frameCount++;
            if (this._frameCount % 60 === 0) {
                console.log('[sidekick] Frame captured:', this._frameCount, 'time:', this.videoElement.currentTime.toFixed(2));
            }
        }
        
        updateFrame() {
            // Wird vom internen Animation-Loop aufgerufen
            if (this._videoPlaying && !this.videoElement.paused && !this.videoElement.ended) {
                const currentTime = this.videoElement.currentTime;
                // Nur bei Zeitänderung updaten
                if (Math.abs(currentTime - this._lastTime) > 0.01) {
                    this._lastTime = currentTime;
                    this._captureFrame();
                }
            }
        }
        
        _startAnimationLoop() {
            if (this._animationRunning) return;
            this._animationRunning = true;
            console.log('[sidekick] Starting animation loop');
            
            const loop = () => {
                if (!this._animationRunning) return;
                this.updateFrame();
                requestAnimationFrame(loop);
            };
            requestAnimationFrame(loop);
        }
        
        _stopAnimationLoop() {
            this._animationRunning = false;
            console.log('[sidekick] Stopping animation loop');
        }
        
        setPlaying(playing) {
            this._videoPlaying = playing;
            console.log('[sidekick] VideoSkin setPlaying:', playing);
            if (playing) {
                this._startAnimationLoop();
            } else {
                this._stopAnimationLoop();
            }
        }
        
        // Manueller Frame-Update (für setVideoTime etc.)
        forceUpdate() {
            this._captureFrame();
        }
        
        get size() {
            if (this.videoElement && this.videoElement.videoWidth) {
                return [this.videoElement.videoWidth, this.videoElement.videoHeight];
            }
            return super.size;
        }
        
        dispose() {
            this._stopAnimationLoop();
            this.videoElement.pause();
            this.videoElement.src = '';
            this._canvas = null;
            this._ctx = null;
            super.dispose();
        }
    };
    
    console.log('[sidekick] VideoSkin class created');
    return VideoSkinClass;
}

class Scratch3SidekickBlocks {

    constructor(runtime) {
        this._runtime = runtime;

        this._libraryReady = false;
        this._loadMQTT();
        
        // Video-System: Videos werden auf Sprites angewendet
        /** @type {Object.<string, object>} VideoSkin instances */
        this._videos = {};
        this._debugCounter = 0;
        
        // Event-Handler für Video-Updates
        runtime.on('PROJECT_STOP_ALL', () => this._resetVideos());
        runtime.on('PROJECT_START', () => this._resetVideos());
        
        // Video-Frame Update Loop - markiert alle spielenden Videos als dirty
        let frameCounter = 0;
        runtime.on('BEFORE_EXECUTE', () => {
            frameCounter++;
            const videoNames = Object.keys(this._videos);
            if (videoNames.length > 0 && frameCounter % 60 === 1) {
                console.log('[sidekick] BEFORE_EXECUTE, videos:', videoNames.length);
            }
            for (const name of videoNames) {
                const videoSkin = this._videos[name];
                if (videoSkin && videoSkin.updateFrame) {
                    videoSkin.updateFrame();
                }
            }
        });
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
            // colour for the menus in the blocks (helles Lila für bessere Sichtbarkeit)
            color2: '#994099',
            // border for blocks and parameter gaps
            color3: '#660066',

            showStatusButton: true,


            // icons to display
            // blockIconURI: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAAAAACyOJm3AAAAFklEQVQYV2P4DwMMEMgAI/+DEUIMBgAEWB7i7uidhAAAAABJRU5ErkJggg==',
            // menuIconURI: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAkAAAAFCAAAAACyOJm3AAAAFklEQVQYV2P4DwMMEMgAI/+DEUIMBgAEWB7i7uidhAAAAABJRU5ErkJggg==',
            menuIconURI: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAIRlWElmTU0AKgAAAAgABQESAAMAAAABAAEAAAEaAAUAAAABAAAASgEbAAUAAAABAAAAUgEoAAMAAAABAAIAAIdpAAQAAAABAAAAWgAAAAAAAACWAAAAAQAAAJYAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAABSgAwAEAAAAAQAAABQAAAAAwIuGFwAAAAlwSFlzAAAXEgAAFxIBZ5/SUgAAAVlpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDYuMC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KGV7hBwAAA+RJREFUOBFNlO1rVmUcx7/n3I97qLkpMwmCHBGxSDdvKgwiyt5Ug1rKEAzW2pOD9aZ/QC0iyDc1a2xuS3qh0XwXPUBhS5aQuM3SrBChjJIgyzV3b/fT7j7f0w55Ha7zu87v972+v6frXEG/+lsk9VZVLYcK15BV5hrrFPKfQMHHYxq7BEYHdCBkrjHT13StG/sDqP9kek8yocRkAOFbzWp+Oa+8UHif1ngqPIC0opUy8ji6Nyc1eTEC8BrQQM76RjXes6xl1fNc1/XXEjnlFlFcLKjwdVHFq8hVZE1Z5VqTEmGYVXYbhIM7tCO5UzvPnNXZypzmfmeOtKr1LnBtxoI5FcQeYzms4QxRtZHyU+g6ka2O1E8ND7ZzONs3pamf4j196htvUlPfDd045JRTGWXCEY0UYkAse9RzG2V4gShfSSm1FaIVZA0ZuLYd1PZ0jIXnPOvZgFrsI9TdAOzxZyL6jvWlUY3+HYMHNdhMSq9D9hKkRZykkW7ErglNnDJuSEP3lVRqd4RjG7Wxf0lLUTNQLkM4B+ZDHJ1kwx8xMakN4fAdiCrIBPZVsA8T6bcxJmSxRF2Ex6jLpF+XVvpRojnCps/JoDMGH9XRdyHpgsRkJTBZyKe71b3BGNZBol3tNyH7hY/zgFZIrQmirB2wYTObu9rUVtuhjpkZzazNa/57uv1bUslnwazQqM3s3UTHPzqog5yKWwbpN0B4PzXai7oXmeG7XKvaJEfrfch7xzVe8hbSf5tMhimRI03RqCfJ4Iv/TvI6KV4KC1r4FfnJdm3/EnUO8BbOZr5OdTk2bSDCTw3HPot4hmy24Ng/Qgu2KXf5RUJ+HuM3yNN4+cobPPZrfyNlOEl6jxNJgYgyyB6a8J7tverdC9lx9lVxHOCww03JNajhaQyHSOkzHExDdK83+OgA7oRkfj19F/5VSuP/Xzj/gO8zRBng1KqHQhQ3V7XqkMsos3R5N+sZzt5jRlCzRRwNoMszhf1O1D22oa8iTpBFFVJ/V0JenraX6VoJ8hL/7h2Apol2mw2keA5xhLTs2Kou0r3bC4ZretV1JDhuqf+H1ylmAtIix2ETgMN7tCdqHOsTpO6riljCFgge9JoMrhDQBQeFPnErYXyErAspsFPYxU//nDdC9iPC9fL5tCoi9IJxwS+cBhEh6fmjiM5nzLJCagWnge0JvnVMx1YRCxAb62cr/2+9bYzL/hEYoZsScMZc7Dpql2KmmRkfEV+aRPkIv1bWaMZf4KLLlHUrpbk90kqLvtrgSrrXo9xj0bW/bowERJVFLdYDugJ5XJpZSN7goJvoMtHnDSaTH7itD/M98S+tD8v6Ma5umQAAAABJRU5ErkJggg==',

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
                // ========== Video Blöcke (Target-basiert) ==========
                {
                    opcode: 'loadVideoURL',
                    text: 'Lade Video [NAME] von [URL]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        },
                        URL: {
                            type: ArgumentType.STRING,
                            defaultValue: 'video.mp4'
                        }
                    }
                },
                {
                    opcode: 'showVideoOnTarget',
                    text: 'Zeige Video [NAME] auf [TARGET]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        },
                        TARGET: {
                            type: ArgumentType.STRING,
                            menu: 'targetMenu',
                            defaultValue: 'Figur1'
                        }
                    }
                },
                {
                    opcode: 'showVideoAndPlay',
                    text: 'Starte Video [NAME] auf [TARGET]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        },
                        TARGET: {
                            type: ArgumentType.STRING,
                            menu: 'targetMenu',
                            defaultValue: 'Figur1'
                        }
                    }
                },
                {
                    opcode: 'stopShowingVideo',
                    text: 'Verstecke Video auf [TARGET]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        TARGET: {
                            type: ArgumentType.STRING,
                            menu: 'targetMenu',
                            defaultValue: 'Figur1'
                        }
                    }
                },
                {
                    opcode: 'startVideo',
                    text: 'Video [NAME] [ACTION]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        },
                        ACTION: {
                            type: ArgumentType.STRING,
                            menu: 'videoActionMenu',
                            defaultValue: 'play'
                        }
                    }
                },
                {
                    opcode: 'setVideoTime',
                    text: 'Setze Video [NAME] auf [TIME] Sekunden',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        },
                        TIME: {
                            type: ArgumentType.NUMBER,
                            defaultValue: 0
                        }
                    }
                },
                {
                    opcode: 'setVideoVolume',
                    text: 'Setze Video [NAME] Lautstärke auf [VOLUME] %',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        },
                        VOLUME: {
                            type: ArgumentType.NUMBER,
                            defaultValue: 100
                        }
                    }
                },
                {
                    opcode: 'setVideoLoop',
                    text: 'Video [NAME] Wiederholen [LOOP]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        },
                        LOOP: {
                            type: ArgumentType.STRING,
                            menu: 'onOffMenu',
                            defaultValue: 'on'
                        }
                    }
                },
                {
                    opcode: 'deleteVideo',
                    text: 'Lösche Video [NAME]',
                    blockType: BlockType.COMMAND,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        }
                    }
                },
                {
                    opcode: 'getVideoAttribute',
                    text: '[ATTRIBUTE] von Video [NAME]',
                    blockType: BlockType.REPORTER,
                    arguments: {
                        ATTRIBUTE: {
                            type: ArgumentType.STRING,
                            menu: 'videoAttributeMenu',
                            defaultValue: 'duration'
                        },
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        }
                    }
                },
                {
                    opcode: 'isVideoPlaying',
                    text: 'Video [NAME] läuft?',
                    blockType: BlockType.BOOLEAN,
                    arguments: {
                        NAME: {
                            type: ArgumentType.STRING,
                            defaultValue: 'meinVideo'
                        }
                    }
                },
                {
                    opcode: 'getCurrentVideoOnTarget',
                    text: 'Aktuelles Video auf [TARGET]',
                    blockType: BlockType.REPORTER,
                    arguments: {
                        TARGET: {
                            type: ArgumentType.STRING,
                            menu: 'targetMenu',
                            defaultValue: 'Figur1'
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
                },
                videoActionMenu: {
                    acceptReporters: false,
                    items: [
                        { text: 'abspielen', value: 'play' },
                        { text: 'pausieren', value: 'pause' },
                        { text: 'stoppen', value: 'stop' }
                    ]
                },
                videoAttributeMenu: {
                    acceptReporters: false,
                    items: [
                        { text: 'Länge', value: 'duration' },
                        { text: 'Position', value: 'currentTime' },
                        { text: 'Lautstärke', value: 'volume' },
                        { text: 'Breite', value: 'width' },
                        { text: 'Höhe', value: 'height' }
                    ]
                },
                onOffMenu: {
                    acceptReporters: false,
                    items: [
                        { text: 'an', value: 'on' },
                        { text: 'aus', value: 'off' }
                    ]
                },
                targetMenu: {
                    acceptReporters: true,
                    items: '_getTargets'
                }
            }
        };
    }

    /**
     * Gibt Liste aller Sprites/Targets für das Menu zurück
     */
    _getTargets() {
        const targets = [{ text: 'mir selbst', value: '_myself_' }];
        
        if (this._runtime.targets) {
            for (const target of this._runtime.targets) {
                if (!target.isStage && target.isOriginal) {
                    targets.push({ text: target.getName(), value: target.getName() });
                }
            }
        }
        
        // Bühne als Option
        targets.push({ text: 'Bühne', value: '_stage_' });
        
        return targets;
    }

    /**
     * Holt Target aus dem Menu-Wert
     */
    _getTargetFromMenu(targetName, util) {
        if (targetName === '_myself_') {
            return util.target;
        }
        if (targetName === '_stage_') {
            return this._runtime.getTargetForStage();
        }
        return this._runtime.getSpriteTargetByName(targetName);
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

    // ========== Video Steuerung (Target-basiert) ==========
    
    /**
     * Setzt alle Videos zurück (bei Projekt-Start/Stop)
     */
    _resetVideos() {
        const renderer = this._runtime.renderer;
        
        // Pausiere alle Videos
        for (const name in this._videos) {
            const videoSkin = this._videos[name];
            if (videoSkin && videoSkin.videoElement) {
                videoSkin.videoElement.pause();
                videoSkin.videoElement.currentTime = 0;
            }
        }
        
        // Setze alle Targets zurück die ein Video zeigen
        if (renderer && this._runtime.targets && VideoSkinClass) {
            for (const target of this._runtime.targets) {
                const drawable = renderer._allDrawables[target.drawableID];
                if (drawable && drawable.skin instanceof VideoSkinClass) {
                    target.setCostume(target.currentCostume);
                }
            }
        }
    }

    /**
     * Lädt ein Video von einer URL
     */
    async loadVideoURL(args) {
        const videoName = Cast.toString(args.NAME);
        const videoSrc = Cast.toString(args.URL);
        
        // Lösche altes Video mit gleichem Namen wenn vorhanden
        this.deleteVideo({ NAME: videoName });
        
        const renderer = this._runtime.renderer;
        if (!renderer) {
            console.warn('[sidekick] Renderer not available');
            return;
        }
        
        // Hole oder erstelle VideoSkin-Klasse
        const VideoSkin = getOrCreateVideoSkinClass(renderer);
        if (!VideoSkin) {
            console.error('[sidekick] Could not create VideoSkin class');
            return;
        }
        
        // Erstelle neue VideoSkin - registriere sie im Renderer
        const skinId = renderer._nextSkinId++;
        const videoSkin = new VideoSkin(skinId, renderer, videoName, videoSrc, this._runtime);
        renderer._allSkins[skinId] = videoSkin;
        this._videos[videoName] = videoSkin;
        
        console.log('[sidekick] Loading video:', videoName, 'from', videoSrc);
        
        // Warte bis Video geladen ist
        return videoSkin.readyPromise;
    }

    /**
     * Löscht ein Video
     */
    deleteVideo(args) {
        const videoName = Cast.toString(args.NAME);
        const videoSkin = this._videos[videoName];
        if (!videoSkin) return;
        
        const renderer = this._runtime.renderer;
        
        // Setze alle Targets zurück die dieses Video zeigen
        if (renderer && this._runtime.targets) {
            for (const target of this._runtime.targets) {
                const drawable = renderer._allDrawables[target.drawableID];
                if (drawable && drawable.skin === videoSkin) {
                    target.setCostume(target.currentCostume);
                }
            }
        }
        
        // Zerstöre die Skin
        if (renderer) {
            renderer.destroySkin(videoSkin._id);
        }
        delete this._videos[videoName];
        
        console.log('[sidekick] Video deleted:', videoName);
    }

    /**
     * Zeigt Video auf einem Sprite/Target
     */
    showVideoOnTarget(args, util) {
        const targetName = Cast.toString(args.TARGET);
        const videoName = Cast.toString(args.NAME);
        const target = this._getTargetFromMenu(targetName, util);
        const videoSkin = this._videos[videoName];
        
        if (!target || !videoSkin) {
            console.warn('[sidekick] showVideoOnTarget: target or video not found', targetName, videoName);
            return;
        }
        
        const renderer = this._runtime.renderer;
        if (renderer) {
            renderer.updateDrawableSkinId(target.drawableID, videoSkin._id);
            console.log('[sidekick] Showing video', videoName, 'on', targetName);
        }
    }

    /**
     * Zeigt Video auf einem Sprite und startet es
     */
    showVideoAndPlay(args, util) {
        const targetName = Cast.toString(args.TARGET);
        const videoName = Cast.toString(args.NAME);
        const target = this._getTargetFromMenu(targetName, util);
        const videoSkin = this._videos[videoName];
        
        if (!target || !videoSkin) {
            console.warn('[sidekick] showVideoAndPlay: target or video not found', targetName, videoName);
            return;
        }
        
        const renderer = this._runtime.renderer;
        if (renderer) {
            renderer.updateDrawableSkinId(target.drawableID, videoSkin._id);
            videoSkin.setPlaying(true);
            videoSkin.videoElement.play();
            console.log('[sidekick] Playing video', videoName, 'on', targetName);
        }
    }

    /**
     * Versteckt Video auf einem Target (setzt Kostüm zurück)
     */
    stopShowingVideo(args, util) {
        const targetName = Cast.toString(args.TARGET);
        const target = this._getTargetFromMenu(targetName, util);
        
        if (!target) return;
        
        target.setCostume(target.currentCostume);
        console.log('[sidekick] Stopped showing video on', targetName);
    }

    /**
     * Startet/Pausiert/Stoppt ein Video
     */
    startVideo(args) {
        const videoName = Cast.toString(args.NAME);
        const action = Cast.toString(args.ACTION);
        const videoSkin = this._videos[videoName];
        
        if (!videoSkin) return;
        
        switch (action) {
            case 'play':
                console.log('[sidekick] Attempting to play video');
                videoSkin.setPlaying(true);
                videoSkin.videoElement.play().then(() => {
                    console.log('[sidekick] Video play started successfully');
                }).catch(e => {
                    console.error('[sidekick] Video play failed:', e);
                    videoSkin.setPlaying(false);
                });
                break;
            case 'pause':
                videoSkin.setPlaying(false);
                videoSkin.videoElement.pause();
                break;
            case 'stop':
                videoSkin.setPlaying(false);
                videoSkin.videoElement.pause();
                videoSkin.videoElement.currentTime = 0;
                videoSkin.forceUpdate();
                break;
        }
        console.log('[sidekick] Video', videoName, action);
    }

    /**
     * Setzt die Video-Zeit
     */
    setVideoTime(args) {
        const videoName = Cast.toString(args.NAME);
        const time = Cast.toNumber(args.TIME);
        const videoSkin = this._videos[videoName];
        
        if (!videoSkin || !videoSkin.videoElement) return;
        
        videoSkin.videoElement.currentTime = Math.max(0, time);
        // Warte kurz bis der Frame geladen ist, dann update
        setTimeout(() => videoSkin.forceUpdate(), 50);
        console.log('[sidekick] Video', videoName, 'time set to', time);
    }

    /**
     * Setzt die Video-Lautstärke
     */
    setVideoVolume(args) {
        const videoName = Cast.toString(args.NAME);
        const volume = Cast.toNumber(args.VOLUME);
        const videoSkin = this._videos[videoName];
        
        if (!videoSkin || !videoSkin.videoElement) return;
        
        videoSkin.videoElement.volume = Math.max(0, Math.min(100, volume)) / 100;
        console.log('[sidekick] Video', videoName, 'volume set to', volume);
    }

    /**
     * Setzt ob das Video wiederholt wird
     */
    setVideoLoop(args) {
        const videoName = Cast.toString(args.NAME);
        const loop = Cast.toString(args.LOOP) === 'on';
        const videoSkin = this._videos[videoName];
        
        if (!videoSkin || !videoSkin.videoElement) return;
        
        videoSkin.videoElement.loop = loop;
        console.log('[sidekick] Video', videoName, 'loop', loop ? 'on' : 'off');
    }

    /**
     * Gibt ein Attribut des Videos zurück
     */
    getVideoAttribute(args) {
        const videoName = Cast.toString(args.NAME);
        const attribute = Cast.toString(args.ATTRIBUTE);
        const videoSkin = this._videos[videoName];
        
        if (!videoSkin || !videoSkin.videoElement) return 0;
        
        switch (attribute) {
            case 'currentTime':
                return Math.round(videoSkin.videoElement.currentTime * 10) / 10;
            case 'duration':
                return Math.round(videoSkin.videoElement.duration * 10) / 10 || 0;
            case 'volume':
                return Math.round(videoSkin.videoElement.volume * 100);
            case 'width':
                return videoSkin.videoElement.videoWidth || 0;
            case 'height':
                return videoSkin.videoElement.videoHeight || 0;
            default:
                return 0;
        }
    }

    /**
     * Prüft ob ein Video läuft
     */
    isVideoPlaying(args) {
        const videoName = Cast.toString(args.NAME);
        const videoSkin = this._videos[videoName];
        
        if (!videoSkin || !videoSkin.videoElement) return false;
        
        return !videoSkin.videoElement.paused && !videoSkin.videoElement.ended;
    }

    /**
     * Gibt das aktuelle Video auf einem Target zurück
     */
    getCurrentVideoOnTarget(args, util) {
        const targetName = Cast.toString(args.TARGET);
        const target = this._getTargetFromMenu(targetName, util);
        
        if (!target) return '';
        
        const renderer = this._runtime.renderer;
        if (!renderer) return '';
        
        const drawable = renderer._allDrawables[target.drawableID];
        const skin = drawable && drawable.skin;
        
        // Prüfe ob die Skin eine VideoSkin ist und gib den Namen zurück
        if (VideoSkinClass && skin instanceof VideoSkinClass) {
            return skin.videoName;
        }
        return '';
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
