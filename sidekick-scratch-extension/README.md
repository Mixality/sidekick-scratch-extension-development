# SIDEKICK Scratch Extension



## Development Notes

1. Problem with "new message from [TOPIC]" HAT block:

- `subscribe` block implementation:

  ```js
  subscribe({ TOPIC }) {
    if (this._mqttConnection) {
        return this._mqttConnection.mqttSubscribe(TOPIC);
    }
  }
  ```

- `mqttSubscribe` block implementation:

  ```js
  subscribe({ TOPIC }) {
    if (this._mqttConnection) {
        return this._mqttConnection.mqttSubscribe(TOPIC);
    }
  }
  ```

--> Problem: The `subscribe` HAT block only returns `true` if there **already** is a message within the queue
    --> But: Scratch **periodically polls** HAT blocks
        --> A message coming up between polls gets "consumed" by `getUltrasonic` (by `.shift()`) is not "spotted" by the HAT

2. Messages "consumed" by `getUltrasonic`

```js
getUltrasonic({ ULTRASONIC }) {
    var ultrasonicTopic = 'sidekick/box/' + ULTRASONIC + "/hand_detected";
    return this._mqttConnection.mqttMessage(ultrasonicTopic) === '1';
}
```

- `.shift()` (of `mqttMessage`): Removes the message
  --> Messages are lost due to calling / invoking the block multiple times / in combination with the HAT block,

3. Possible Solution:
   1. The HAT block automatically subscribes once used.
   2. Seperate flag for a "new message": --> Thus reliably triggering the HAT block.
   3. `getUltrasonic` reads (not: consumes) the last message or: subscribes automatically as well.
