# ROS 2 Mower App 🚜

En moderne, lynhurtig kontrol-app bygget i Flutter til at styre en custom autonom robotplæneklipper. Appen fungerer som det primære interface mellem brugeren og robottens ROS 2 backend via WebSockets.

Projektet er designet til at håndtere en avanceret hardware-stack, hvor et Worx Landroid-chassis er blevet ombygget og opgraderet med ESP32-mikrocontrollere, dobbelte VESC-controllere til præcis motorstyring og et RTK GNSS-modul til centimeterpræcis navigation.

## ✨ Funktioner

* **Live Kortlægning:** Real-time visning af robottens position, rute og heading på et interaktivt kanvas.
* **Telemetri & Metrics:** Overvågning af vitale systemdata såsom batteriniveau, fremdrift, main controller CPU-load og RTK-status (Fix Type og satellit-antal).
* **Manuel Kontrol:** Hurtige adgangsknapper til at starte klipning, stoppe maskinen eller sende den direkte hjem til ladestationen.
* **Køreplan (Schedule):** Intuitiv opsætning af klippe-skema med valg af specifikke ugedage og starttidspunkter.
* **Live Videostream (WIP):** Klargjort til WebRTC-integration for at vise robottens kamera-feed og YOLO-baserede computer vision output direkte i appen.

## 🛠️ Teknologistak

* **Frontend:** [Flutter](https://flutter.dev/) & Dart (Understøtter Android, iOS, Windows, og Web)
* **Backend Kommunikation:** WebSockets (JSON-baseret topic publishing/subscribing)
* **Robot OS:** ROS 2 (Håndterer path planning, sensor fusion og motorstyring)

## 🚀 Kom Godt I Gang

### Forudsætninger
For at bygge og køre projektet skal du have følgende installeret:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Testet på channel stable)
* Android Studio (til Android Emulator og SDK tools) eller en tilsluttet fysisk enhed
* En aktiv ROS 2 bridge/websocket-server (hvis du ikke bruger den indbyggede simulator-tilstand)

### Installation

1. Klon sporet:
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