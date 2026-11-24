# OmniMow

[![OmniMow Android & iOS Build](https://github.com/Ragsie/OmniMow_App/actions/workflows/main.yml/badge.svg)](https://github.com/Ragsie/OmniMow_App/actions/workflows/main.yml)
[![Latest Release](https://img.shields.io/github/v/release/Ragsie/OmniMow_App?label=latest%20release)](https://github.com/Ragsie/OmniMow_App/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-green.svg)](#)

OmniMow is the Flutter app (Android and iOS) for the ROS 2 based [OmniMow](https://github.com/Ragsie/OmniMow) mower software for DIY robot lawn mowers. It talks to the mower's backend on the local network (port 9000).

## What the app does

### Dashboard and map
* The map fills the screen and can be panned and zoomed. It shows the lawn zones, the route driven so far, the charging station and the robot with its heading, on the mower's visual SLAM map (no GPS).
* Battery and camera calibration at the top. Tap calibration to see the result or start a new one.
* Start/pause, send home and live camera at the bottom, plus the schedule, metrics and "Map lawn", where the mower drives along the lawn edge and saves it as a zone.
* Light, dark or system theme. The cards are frosted glass (`GlassCard`).

### Finding the mower
* On the first start the app scans the phone's local networks (/24) for the backend on port 9000. A device only counts if its `/openapi.json` says OmniMow, so other devices with that port open are skipped. The scan stops after 5 seconds and can be started again from the mower list.
* A found mower gets a name and is saved on the phone. If nothing is found, you type in the IP address.
* The app connects to the last used mower when it starts, and reconnects by itself if the connection closes.

### Metrics
* Cutter motor current with a load bar, battery voltage, current and temperature.
* Distance driven, operating time and charge cycles.
* CPU load and temperature, RAM, Wi-Fi signal, camera calibration and localization, the position of the robot and the charging station, and the rain sensor.

### More
* Live video from the mower's camera with the AI detections drawn on it (WebRTC, port 8889).
* Weekly schedule (days, start time, hours per day), saved on the mower. It can be switched off.
* Rain delay: how long the mower waits after rain before it mows again, saved on the mower. It can be skipped from the dashboard.
* Local notifications for low battery (below 20 %), camera calibration, stuck, rain, returning to the dock, charging and new mower software. Each one can be switched off in Settings (returning to the dock and charging are off by default). They only arrive while the app is running and connected to the mower.
* App updates from GitHub releases: on Android the app downloads the APK and opens the installer, on iOS it opens the release page (sideload with Sideloadly or AltStore).
* Mower software updates: the app shows when a new release is out and can install it on the mower.

## Credits
* [OpenMower](https://github.com/ClemensElflein/openmower) – the open-source DIY robot mower project.
* [ROS 2](https://www.ros.org/) – robotics middleware.
* [VESC](https://vesc-project.com/) – open-source motor controllers.

## Links
* [App Wiki](https://github.com/Ragsie/OmniMow_App/wiki) - installing the app on Android and iOS, using it, and building it from source.
* [Mower Wiki](https://github.com/Ragsie/OmniMow/wiki) - the mower software the app talks to.

## Support
If OmniMow is useful to you, you can [buy me a coffee](https://buymeacoffee.com/ragsie).
