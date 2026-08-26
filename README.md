# ROS 2 Mower App 🚜

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

* **Frontend:** [Flutter](https://flutter.dev/) & Dart (supports Android, iOS, Windows, and Web)
* **Backend Communication:** WebSockets (JSON-based topic publishing/subscribing)
* **Robot OS:** [ROS 2 Mower](https://github.com/Ragsie/worx-ros2-mower) (handles path planning, sensor fusion, and motor control)

---

## 📥 Installation Guide

Find step-by-step guides on how to install and set up the app on your mobile devices in our Wiki documentation:
* [How to install on Android (Wiki Docs)](https://github.com/Ragsie/worx-ros2-mower/wiki) *(eller indsæt det direkte link til din Android-guide)*
* [How to install on iPhone / iOS via Sideloadly (Wiki Docs)](https://github.com/Ragsie/worx-ros2-mower/wiki) *(eller indsæt det direkte link til din iOS-guide)*

### Automated Builds & Releases via GitHub Actions
The repository is configured with automated CI/CD workflows via GitHub Actions. Every push to the main branch automatically compiles both the Android APK and the iOS app, manages auto-incrementing build numbers based on commits, and publishes them directly to the repository's **Releases** page.

---

## ROS 2 Mower Backend

The app is intended to work with the [worx-ros2-mower](https://github.com/Ragsie/worx-ros2-mower) project. That repository contains the ROS 2 mower-side software and is the place to configure the robot, its sensors, navigation, and hardware controllers.

The Flutter app connects to the robot's WebSocket bridge at `ws://<robot-ip>:9090`. The ROS 2 bridge must be running and reachable from the phone or device before the dashboard can be opened.

## Implementation Notes
* **ROS bridge:** A selected robot connects through `ws://<robot-ip>:9090`. Incoming messages are expected to use ROS topics such as `/battery_status`, `/rtk/status`, `/mower/status`, `/mower/metrics`, `/odom`, and `/gps/fix`.
* **Commands:** Manual commands are published to `/mower/command`; schedules are published to `/mower/schedule` as JSON payloads.
* **Notifications:** Notification preferences are stored locally with `shared_preferences` under the `notif_*` keys.
* **Live video:** The WebRTC screen expects signaling on port `8889` at `/webrtc`. The signaling server and camera stream still need to be provided by the robot system.
* **Position data:** The `/odom` and `/gps/fix` handlers are placeholders. Map coordinates must be mapped from the real ROS message format before live positioning is enabled.

---

## ☕ Support The Project
If this project helped you or inspired your own build, consider buying me a cup of coffee. It would make my day and support me in developing more!

| Coin | QR | Address |
| :-- | :--- | :---: |
| **Bitcoin Cash** | <img width="160" height="161" alt="qrcode" src="https://github.com/user-attachments/assets/254aece9-8957-4d34-812c-885ac2e839fa" /> | `bitcoincash:qzp4c7klef8q6gxycvc84dx0fnhnfxkkpy6xda56h3` |
| **Bitcoin** | <img width="160" height="162" alt="image" src="https://github.com/user-attachments/assets/e5b1cd3d-fd26-46fc-88db-2aa931b4f5d4" /> | `3QrAPVGC3aypf3LG5DYYRnjwjKuFMzkeJE` |
