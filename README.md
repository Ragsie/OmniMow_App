# ROS 2 Mower App 🚜

A modern, fast control app built in Flutter for operating a custom autonomous robotic lawn mower. The app provides the primary interface between the user and the robot's ROS 2 backend through WebSockets.

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

## 🚀 Getting Started

### Prerequisites
To build and run the project, install the following:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (tested on the stable channel)
* Android Studio (for the Android Emulator and SDK tools) or a connected physical device
* An active ROS 2 bridge/WebSocket server connected to the mower

### Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/dit-brugernavn/ros_mower_app.git](https://github.com/dit-brugernavn/ros_mower_app.git)
   cd ros_mower_app
   ```

2. Fetch dependencies and run the app:
   ```bash
   flutter pub get
   flutter run
   ```

### Build an APK Locally

Anyone with the Flutter and Android prerequisites can build the Android APK locally:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

The generated APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For a quick development build, use `flutter build apk --debug` instead. A release APK should be signed with your own Android keystore before distribution through an app store or to production devices.

### Build on GitHub

The APK can also be built by GitHub Actions. Open the repository's **Actions** tab, run the Android build workflow, and download the generated APK from the workflow run's **Artifacts** section. This lets users build the app without installing Flutter locally.

The exact workflow name and artifact name depend on the workflow configuration in the repository.

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