# OmniMow 🚜

[![Build and Release OmniMow](https://github.com/Ragsie/OmniMow_App/actions/workflows/build.yml/badge.svg)](https://github.com/Ragsie/OmniMow_App/actions/workflows/build.yml)

A modern, fast control app built in Flutter for operating a custom autonomous robotic lawn mower. The app provides the primary interface between the user and the robot's ROS 2 backend through WebSockets.

> **Alpha software:** This project is still in the alpha phase. Bugs, incomplete features, connection issues, and other unexpected behavior may occur. Use it for testing and development, and avoid relying on it for unattended production operation.

The project is designed to handle an advanced hardware stack in which a Worx Landroid chassis has been rebuilt and upgraded with ESP32 microcontrollers, dual VESC controllers for precise motor control, and an RTK GNSS module for centimeter-level navigation.

## ✨ Features

* **Live Mapping:** Real-time display of the robot's position, route, and heading on an interactive canvas.
* **Telemetry & Metrics:** Monitoring of vital system data such as battery level, progress, main controller CPU load, and RTK status (fix type and satellite count).
* **Manual Control:** Quick-access buttons to start mowing, stop the machine, or send it directly home to the charging station.
* **Schedule:** Intuitive setup of mowing schedules with selected weekdays and start times.
* **Live Video Feed (WIP):** Prepared for WebRTC integration to display the robot's camera feed and YOLO-based computer vision output directly in the app.

## 🛠️ Technology Stack

* **Frontend:** [Flutter](https://flutter.dev/) & Dart (supports Android, iOS, Windows, and Web).
* **Backend Communication:** WebSockets (JSON-based topic publishing/subscribing).
* **Robot OS:** [ROS 2 Mower](https://github.com/Ragsie/OmniMow) (handles path planning, sensor fusion, and motor control).

---

## 📥 Installation Guide

Find step-by-step guides on how to install and set up the app on your mobile devices in our Wiki documentation:
* [How to install on Android (Wiki Docs)](https://github.com/Ragsie/OmniMow_App/wiki/Android-Installation)
* [How to install on iPhone / iOS via Sideloadly (Wiki Docs)](https://github.com/Ragsie/OmniMow_App/wiki/iOS-Installation-Sideloadly)

### Automated Builds & Releases via GitHub Actions
The repository is configured with automated CI/CD workflows via GitHub Actions. Every push to the main branch automatically compiles both the Android APK and the iOS app, manages auto-incrementing build numbers based on commits, and publishes them directly to the repository's **Releases** page.

---

## ROS 2 Mower Backend

The app is intended to work with the [OmniMow](https://github.com/Ragsie/OmniMow) project. That repository contains the ROS 2 mower-side software and is the place to configure the robot, its sensors, navigation, and hardware controllers.

The Flutter app connects to the robot's WebSocket bridge at `ws://<robot-ip>:9090`. The ROS 2 bridge must be running and reachable from the phone or device before the dashboard can be opened.

## Implementation Notes
* **ROS bridge:** A selected robot connects through `ws://<robot-ip>:9090`. Incoming messages are expected to use ROS topics such as `/battery_status`, `/rtk/status`, `/mower/status`, `/mower/metrics`, `/odom`, and `/gps/fix`.
* **Commands:** Manual commands are published to `/mower/command`; schedules are published to `/mower/schedule` as JSON payloads.
* **Notifications:** Notification preferences are stored locally with `shared_preferences` under the `notif_*` keys.
* **Live video:** The WebRTC screen expects signaling on port `8889` at `/webrtc`. The signaling server and camera stream still need to be provided by the robot system.
* **Position data:** The `/odom` and `/gps/fix` handlers are placeholders. Map coordinates must be mapped from the real ROS message format before live positioning is enabled.
* **Built in app update on android, Ios will get a pop up.
---

Acknowledgements & Credits
As OmniMow is built to support and empower the amazing open-source and DIY robotics community, and we now accept donations, we would like to extend a huge thank you to the projects, libraries, and developers that have made this app possible. This project truly stands on the shoulders of giants:

Core Platforms & Projects
ROS 2 (Robot Operating System) – The powerful middleware framework that manages the robot's logic, sensors, and actuators.
Flutter & Dart – Google's incredible UI toolkit, enabling us to deliver a fast, modern, and responsive user interface for both Android and iOS.
Hardware & Computer Vision
VESC (Benjamin Vedder) – For the essential and widely-used open-source motor control system that delivers precise wheel and cutter motor control along with detailed telemetry.
micro-ROS – Enabling the seamless integration of microcontrollers (like the ESP32) directly with the robot's ROS 2 backend.
YOLO (You Only Look Once) – The state-of-the-art computer vision model that enables real-time, intelligent object detection directly within the robot's live video stream.
Essential Flutter Packages (Dependencies)
A special thanks to the developers of these open-source packages, which are critical to the application's core functionality:

flutter_webrtc – Enables ultra-low latency live video streaming directly from the robot's camera.
open_filex – Ensures the app can securely and seamlessly trigger downloaded APK updates on modern Android versions.
web_socket_channel – Powers the robust WebSocket bridge connecting the mobile frontend to the robot's ROS 2 telemetry and manual controls.
flutter_local_notifications – Handles the local push notification system on mobile devices, alerting users about low battery, lost RTK connections, or when the mower gets stuck.
Distribution & Tooling
Sideloadly – Simplifies sideloading and auto-updating the app on iOS devices for users without a paid Apple Developer account.
GitHub Actions – Automates our entire CI/CD pipeline, signing release APKs, and auto-generating changelogs from commit histories.

## ☕ Support The Project
If this project helped you or inspired your own build, consider buying me a cup of coffee. It would make my day and support me in developing more!
please note that this project is, and will always remain, **100% free and open-source** under the **GNU GPLv3 License** in accordance with the licenses of our upstream dependencies.

[![Buy Me A Coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=ragsie&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff)](https://buymeacoffee.com/ragsie)

| Coin | QR | Address |
| :-- | :--- | :---: |
| **Bitcoin Cash** | <img width="160" height="161" alt="qrcode" src="https://github.com/user-attachments/assets/254aece9-8957-4d34-812c-885ac2e839fa" /> | `bitcoincash:qzp4c7klef8q6gxycvc84dx0fnhnfxkkpy6xda56h3` |
| **Bitcoin** | <img width="160" height="162" alt="image" src="https://github.com/user-attachments/assets/e5b1cd3d-fd26-46fc-88db-2aa931b4f5d4" /> | `3QrAPVGC3aypf3LG5DYYRnjwjKuFMzkeJE` |
