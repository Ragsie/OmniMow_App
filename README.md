# 🚜 OmniMow

[![OmniMow CI/CD Rolling Release Pipeline](https://github.com/Ragsie/OmniMow/actions/workflows/build.yml/badge.badge.svg)](https://github.com/Ragsie/OmniMow/actions)
[![Latest Release](https://img.shields.io/github/v/release/Ragsie/OmniMow?label=latest%20release)](https://github.com/Ragsie/OmniMow/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-green.svg)](#)

**OmniMow** is a high-performance, beautiful, and modular cross-platform mobile client built using Google's **Flutter** framework. It acts as a powerful controller and dashboard for autonomous DIY robotic lawn mowers, specifically designed to bridge seamlessly with a **ROS 2** and **OpenMow** robotic backend. 

By leveraging real-time WebSockets, WebRTC, and local push notifications, OmniMow provides robotic lawn mower enthusiasts with a professional, comprehensive monitoring and control panel directly in their pocket.

---

## ✨ Core Features

* **🔌 Real-Time FastAPI WebSocket Connection (Port 8000):** Consumes an enriched, high-density JSON telemetry payload every second, including battery health metrics, system diagnostics, and motor power outputs.
* **🗺️ RTK GNSS Path Mapping:** Projects centimeter-precise Latitude and Longitude coordinates onto a real-time local canvas grid map, drawing the exact path history of your mower as it cuts.
* **🔋 Advanced Battery Management System (BMS) Monitoring:** Displays detailed real-time metrics for battery voltage ($V$), battery current ($A$), battery temperature ($°C$), and charge cycles.
* **✂️ Cutter Motor Telemetry:** Keeps track of blade activity, cutter motor current (Amps), cutter RPM, power consumption (Watts), and triggers visual overload warnings for heavy grass.
* **📹 WebRTC Live YOLOv26 Camera Feed (Port 8889):** Streams an ultra-low latency live video feed featuring YOLO computer vision object-detection overlays directly from your mower's camera.
* **📅 Interactive Weekly Scheduler:** A built-in weekly calendar and time-picker interface allowing you to easily schedule cutting days and push the JSON schedule directly to the robot.
* **🤖 Fleet Manager:** Easily save, name, edit, and delete multiple robotic mower IP addresses within a localized, persistent list using a clean pop-up dashboard.
* **🔔 Smart Notification Service:** Triggers local push alerts for critical states like Low Battery (< 20%), Loss of RTK Centimeter Fix, Mower Stuck, Docking, or Charging. Includes fully customizable notification toggles.
* **🔄 Seamless In-App Updates:** Features an intelligent self-updater utilizing semantical version checking via the GitHub API. It automatically detects, downloads, and launches APK installations for stable or rolling releases.
* **🎨 Material 3 Dark/Light Themes:** Dynamically matches your phone's operating system theme (System, Dark, or Light Mode) with beautiful, glowing greenAccent highlight details.

---

## OmniMow Backend

The app is intended to work with the [OmniMow](https://github.com/Ragsie/OmniMow) project. That repository contains the ROS 2 mower-side software and is the place to configure the robot, its sensors, navigation, and hardware controllers.

The Flutter app connects to the robot's WebSocket bridge at `ws://<robot-ip>:9090`. The ROS 2 bridge must be running and reachable from the phone or device before the dashboard can be opened.

---

## 💖 Standing on the Shoulders of Giants

OmniMow is built to empower the open-source and DIY robotics community. We extend a huge thank you to:
* **[OpenMow](https://github.com/ClemensElflein/openmow)** – The incredible pioneering DIY lawn mower firmware project.
* **[ROS 2](https://www.ros.org/)** – The powerhouse framework behind robot logic and communication.
* **[VESC](https://vesc-project.com/)** – Outstanding open motor controller technology and telemetry.
* **[Flutter](https://flutter.dev/)** – Google's awesome UI framework.

---

## ☕ Support the Development

If OmniMow made your lawn mower smarter or your DIY journey more enjoyable, please consider buying me a coffee to keep development alive and rolling!

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-yellow?style=for-the-badge&logo=buy-me-a-coffee)](https://buymeacoffee.com/ragsie)

| Coin | QR | Address |
| :-- | :--- | :---: |
| **Bitcoin Cash** | <img width="160" height="161" alt="qrcode" src="https://github.com/user-attachments/assets/254aece9-8957-4d34-812c-885ac2e839fa" /> | `bitcoincash:qzp4c7klef8q6gxycvc84dx0fnhnfxkkpy6xda56h3` |
| **Bitcoin** | <img width="160" height="162" alt="image" src="https://github.com/user-attachments/assets/e5b1cd3d-fd26-46fc-88db-2aa931b4f5d4" /> | `3QrAPVGC3aypf3LG5DYYRnjwjKuFMzkeJE` |

---

## 📖 Quick Links
* **[Installation & Setup Guide](INSTALL.md)** - Learn how to install OmniMow on Android and iOS (Sideloading).
* **[Consolidated Codebase](all_code_english_consolidated-v3.md)** - View the entire clean, compiled source code of the project.


---