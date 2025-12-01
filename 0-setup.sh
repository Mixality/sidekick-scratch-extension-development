#!/bin/bash
set -e

echo "Verifying location of Scratch source is known"
if [ -z "$SCRATCH_SRC_HOME" ]; then
    echo "Error: SCRATCH_SRC_HOME environment variable is not set."
    exit 1
fi

echo "Checking if Scratch source has already been customized"
if [ -e $SCRATCH_SRC_HOME/patched ]; then
    exit 1
fi

echo "Getting the location of this script"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

echo "Adding extension to Scratch source"
cd $SCRATCH_SRC_HOME/scratch-vm/src/extensions
ln -s $DIR/sidekick-scratch-mqtt-extension scratch3_sidekickmqtt
ln -s $DIR/sidekick-scratch-extension scratch3_sidekick

echo "Patching Scratch source to enable extension"
cd $SCRATCH_SRC_HOME/scratch-vm
git apply $DIR/patches/scratch-vm.patch
mv package.json $DIR/dependencies/package.json
ln -s $DIR/dependencies/package.json .
mv package-lock.json $DIR/dependencies/package-lock.json
ln -s $DIR/dependencies/package-lock.json .
cd $SCRATCH_SRC_HOME/scratch-gui
git apply $DIR/patches/scratch-gui.patch

echo "Copying in the SIDEKICK MQTT Scratch extension files"
mkdir -p src/lib/libraries/extensions/sidekickmqtt
cd src/lib/libraries/extensions/sidekickmqtt
ln -s $DIR/sidekick-mqtt.png sidekick-mqtt.png
ln -s $DIR/sidekick-mqtt-small.png sidekick-mqtt-small.png

cd $SCRATCH_SRC_HOME/scratch-gui

echo "Copying in the SIDEKICK Scratch extension files"
mkdir -p src/lib/libraries/extensions/sidekick
cd src/lib/libraries/extensions/sidekick
ln -s $DIR/sidekick.svg sidekick.svg
ln -s $DIR/sidekick-small.svg sidekick-small.svg

echo "Marking the Scratch source as customized"
touch $SCRATCH_SRC_HOME/patched