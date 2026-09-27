# 🚜 OmniMow



[![OmniMow CI/CD Rolling Release Pipeline](https://github.com/Ragsie/OmniMow_App/actions/workflows/build.yml/badge.badge.svg)](https://github.com/Ragsie/OmniMow_App/actions)
[![Latest Release](https://img.shields.io/github/v/release/Ragsie/OmniMow?label=latest%20release)](https://github.com/Ragsie/OmniMow_App/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-green.svg)](#)


**OmniMow** is a premium, high-performance, and modular cross-platform mobile client built using Google's **Flutter** framework. It is engineered as a state-of-the-art dashboard and controller for autonomous DIY robotic lawn mowers, bridging seamlessly with a **ROS 2** and **OpenMow** robotic backend.

This latest version features a **comprehensive premium UI Overhaul** inspired directly by the luxury **Segway Navimow** design aesthetic, introducing a fully integrated glassmorphic (frosted glass) interface, dark/light theme optimization, and intelligent network-level auto-discovery.

---

## ✨ Premium Highlights

### 🎨 Segway Navimow UI Overhaul
* **Glassmorphic HUD Design:** Widgets, controls, and telemetry pills float gracefully on premium frosted glass cards (`GlassCard`) utilizing dynamic, real-time background blurring (`BackdropFilter`).
* **Material 3 Light & Dark Themes:** Fully optimized themes that adapt seamlessly:
  * *Light Mode:* Premium off-white backdrop (`0xFFF5F6FA`) with deep slate typography, translucent white glass cards, and vivid emerald-green accents.
  * *Dark Mode:* Deep midnight-charcoal backdrop (`0xFF0C0C0E`) with frosted dark matte cards and glowing neon-green highlights.
* **Map-First Experience:** The interactive map covers the entire viewport, transforming the device into a spatial control deck.

### 📡 Intelligent Auto-Discovery Onboarding (First-Run)
* **Zero-Configuration Setup:** On its very first launch (when the mower list is empty), the app boots directly into an automated onboarding radar-scanning screen.
* **Asynchronous Subnet Scanning:** Performs extremely fast, concurrent network-level socket checks across active subnets (scanning IP addresses sequentially on the optimized FastAPI **port 8000**).
* **Throttling & Timeout protection:** Features a strict 5-second scanner timeout. Throttling is applied to UI updates (every 8 IPs) to maintain a perfectly smooth, jitter-free **60 FPS radar animation**.
* **One-Tap Guided Setup:** Instantly detects active mowers, prompts the user to name them, saves them persistently in shared preferences, and routes straight to the live dashboard.
* **Seamless Fallback:** Instantly falls back to a clean manual configuration if no robot is discovered automatically.

### 🗺️ Map-First Infinite Technical Grid
* **No Solid Green Blocks:** Replaced the heavy, solid green boundary blocks with a completely open, technical layout.
* **Infinite Blueprint Grid:** Features an elegant, subdued technical grid background (4% visibility) that dynamically updates on zoom/pan via `InteractiveViewer`.
* **Docking Station Anchor:** Draws an elegant reference point (blue-glowing node) right in the center of the grid map.
* **Pulsing GPS Beacon & Radar Halo:** The active robot is represented as a white pearl surrounded by a large, pulsing green radar circle indicating centimeter-accurate RTK-GPS status.
* **Real-Time Direction Arrow:** Calculates moving segments dynamically to draw a sharp directional arrow on top of the robot, indicating its exact heading.

### 🔋 Diagnostics & Nerd Metrics
* **Cutter Motor Load Telemetry:** Monitors blade activation, real-time current draw (Amps), rotational speed (RPM), and active power wattage (W) with a dynamic load bar indicator.
* **BMS Battery System Diagnostics:** Live transparency of battery health including exact voltage, charging/discharging current, operating temperature (°C), and total charge cycles.
* **Operating Statistics:** Tracks total distance traveled (km), runtime hours, and system CPU diagnostic loads.

---

## 🛠️ Complete Feature Registry

* **🔌 Real-Time FastAPI WebSockets:** Feeds high-density JSON telemetry directly to the client every second.
* **📹 WebRTC Live YOLO Camera Feed (Port 8889):** Streams an ultra-low latency live video signal from the mower with YOLO computer vision object-detection overlays.
* **📅 Interactive Weekly Scheduler:** A sleek day-chip selector and time-picker that pushes the custom scheduled tasks directly to the robot.
* **🔔 Smart Local Notifications:** Triggers local push alerts for critical events (Low Battery < 20%, Loss of RTK Centimeter Fix, Mower Stuck, Returning to Dock, Charging) with toggles inside Settings.
* **🔄 Asynchronous GitHub Updater:** Independent GitHub API check that detects rolling or stable releases, downloads updates in-app, and executes a secure self-installation.

---

## 💖 Credits & Support

OmniMow is built to empower the open-source and DIY robotics community. We extend our warmest thanks to:
* **[OpenMower](https://github.com/ClemensElflein/openmower)** – The pioneering firmware behind autonomous DIY lawn mowing.
* **[ROS 2](https://www.ros.org/)** – The powerhouse robotics middleware.
* **[VESC](https://vesc-project.com/)** – Outstanding motor controller and telemetry technology.

---

## 📖 Quick Links
* **[Installation & Setup Guide](INSTALL.md)** - Guide to installing OmniMow on Android and iOS devices.
* **[Comprehensive Design & Overhaul Report](omnimow_full_navimow_overhaul-v10.md)** - View the full Navimow UI-overhaul specifications.
* **[Consolidated Production Codebase](all_code_english_consolidated-v12.md)** - View the entire clean, compiled source code of the project.

---

## ☕ Support the Development

If OmniMow made your lawn mower smarter or your DIY journey more enjoyable, please consider buying me a coffee to keep development alive and rolling!

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-yellow?style=for-the-badge&logo=buy-me-a-coffee)](https://buymeacoffee.com/ragsie)

| Coin | QR | Address |
| :-- | :--- | :---: |
| **Bitcoin Cash** | <img width="160" height="161" alt="qrcode" src="https://github.com/user-attachments/assets/254aece9-8957-4d34-812c-885ac2e839fa" /> | `bitcoincash:qzp4c7klef8q6gxycvc84dx0fnhnfxkkpy6xda56h3` |
| **Bitcoin** | <img width="160" height="162" alt="image" src="https://github.com/user-attachments/assets/e5b1cd3d-fd26-46fc-88db-2aa931b4f5d4" /> | `3QrAPVGC3aypf3LG5DYYRnjwjKuFMzkeJE` |

---

