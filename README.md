# ROS 2 Mower App 🚜

A modern, fast control app built in Flutter for operating a custom autonomous robotic lawn mower. The app provides the primary interface between the user and the robot's ROS 2 backend through WebSockets.

The project is designed to handle an advanced hardware stack in which a Worx Landroid chassis has been rebuilt and upgraded with ESP32 microcontrollers, dual VESC controllers for precise motor control, and an RTK GNSS module for centimeter-level navigation.

## ✨ Funktioner

* **Live Mapping:** Real-time display of the robot's position, route, and heading on an interactive canvas.
* **Telemetry & Metrics:** Monitoring of vital system data such as battery level, progress, main controller CPU load, and RTK status (fix type and satellite count).
* **Manual Control:** Quick-access buttons to start mowing, stop the machine, or send it directly home to the charging station.
* **Schedule:** Intuitive setup of mowing schedules with selected weekdays and start times.
* **Live Video Feed (WIP):** Prepared for WebRTC integration to display the robot's camera feed and YOLO-based computer vision output directly in the app.

## 🛠️ Teknologistak

* **Frontend:** [Flutter](https://flutter.dev/) & Dart (supports Android, iOS, Windows, and Web)
* **Backend Kommunikation:** WebSockets (JSON-baseret topic publishing/subscribing)
* **Robot OS:** ROS 2 (handles path planning, sensor fusion, and motor control)

## 🚀 Getting Started

### Prerequisites
To build and run the project, install the following:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (tested on the stable channel)
* Android Studio (for the Android Emulator and SDK tools) or a connected physical device
* An active ROS 2 bridge/WebSocket server (unless you use the built-in simulator mode)

### Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/dit-brugernavn/ros_mower_app.git](https://github.com/dit-brugernavn/ros_mower_app.git)
   cd ros_mower_app

---

## ☕ Support The Project
If this project helped you or inspired your own build, consider buying me a cup of coffee. It would make my day and support me in developing more!

| Coin | QR | Address |
| :-- | :--- | :---: |
| **Bitcoin Cash** | <img width="160" height="161" alt="qrcode" src="https://github.com/user-attachments/assets/254aece9-8957-4d34-812c-885ac2e839fa" /> | `bitcoincash:qzp4c7klef8q6gxycvc84dx0fnhnfxkkpy6xda56h3` |
| **Bitcoin** | <img width="160" height="162" alt="image" src="https://github.com/user-attachments/assets/e5b1cd3d-fd26-46fc-88db-2aa931b4f5d4" /> | `3QrAPVGC3aypf3LG5DYYRnjwjKuFMzkeJE` |