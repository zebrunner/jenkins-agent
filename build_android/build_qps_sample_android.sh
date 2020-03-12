#!/bin/bash
set -xe
git clone https://github.com/qaprosoft/qps-sample-android.git
cd qps-sample-android
gradle wrapper
./gradlew assembleDebug
