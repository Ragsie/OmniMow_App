# Changelog – OmniMow app (app_test)

Alle ændringer i appen. Nyeste øverst.

## 2026-10-23 – Opdatering af mower-softwaren

- **Appen fortæller, når der er en ny version af mower-softwaren.** Mower'en tjekker selv GitHub for en ny release hver time og sender det til appen (`software_update` i status). Appen viser en notifikation én gang pr. release og et opdateringsikon øverst på dashboardet.
- **Opdater mower'en fra appen.** Under *Indstillinger → Mower Software* ser du den installerede version, hvad der er nyt, og kan trykke *Install update* (`POST /api/software/update`). Mower'en skal stå stille eller være i laderen. Den bygger og genstarter sine services, og appen forbinder igen af sig selv og giver besked, når opdateringen er færdig eller fejlede.
- *Check now* beder mower'en tjekke med det samme (`POST /api/software/check`).
- Ny notifikationsindstilling: *Mower Software Updates*.
- Kræver mower-softwaren fra `dev`-branchen i `Ragsie/testing` (eller nyere). Robotten henter opdateringer fra releases i `Ragsie/OmniMow`.

## 2026-10-22 – Live video

- **Livevideoen virker nu med mower'ens nye `video_stream`-service** (`ws://<ip>:8889/webrtc`). Appen beder nu om at modtage video, når den laver sit WebRTC-offer. Før indeholdt offeret ingen video-sektion, så mower'en kunne ikke sende billede.

## 2026-10-16 – Release-branchen (`realease`)

- `realease` er sat til at matche den nyeste kode igen. De filer, der var uploadet til branchen, var en ældre GPS-version uden kamerakalibrering, zoner og rettelserne nedenfor.
- Release-buildet hedder **OmniMow** med app-id'et **`com.omnimow.app`**. APK-filer, releases og workflowet hedder også OmniMow.
- Workflowet bygger igen **både Android (APK) og iOS** (usigneret `OmniMow-latest-ios-unsigned.zip` til Sideloadly/AltStore). iOS-bundle-id'et er også `com.omnimow.app`.
- Testbuildet på `main` hedder stadig `omnimow-test` med app-id'et `com.omnimow.test`, så de to versioner kan ligge side om side på telefonen.

## 2026-10-16 – Telemetri og metrics

- **RAM-forbrug** vises på metrics-skærmen som brugt / total MB og procent. Det kræver den nye backend.
- **Kalibreringsstatus hentes via REST** (`/api/calibration`) hvert 5. sekund, mens appen er forbundet. Så vises den, også selv om backenden ikke sender den over WebSocket.
- **Mere robust læsning af telemetri.** Felter som `state`, `charge_cycles`, `cutter_rpm` og `cutter_status` accepteres nu som heltal, decimaltal eller tal i tekst. Før stoppede læsningen ved en uventet type, og resten af beskeden blev droppet. Det gjorde blandt andet, at CPU og wifi aldrig blev vist.
- Kniv- og RPM-værdier nulstilles ikke længere af beskeder, der ikke indeholder dem.

## 2026-10-16 – Forbindelse

- **Auto-connect ved opstart.** Appen forbinder til den robot, der sidst var i brug, eller til den første på listen. Før blev IP'en gemt, men aldrig brugt.
- **Netværksscanningen godtager kun en rigtig OmniMow.** En fundet enhed med port 9000 åben bliver tjekket via `/openapi.json`, og den godtages kun, hvis svaret indeholder "OmniMow". Før kunne scanningen vælge en anden enhed på netværket.
- Hvis scanningens grænse på 5 sekunder udløber, lige efter at en robot er fundet, bliver fundet ikke længere smidt væk.
- **Fejlbeskeder ved forbindelse.** Skærmen med robotter viser, hvorfor WebSocket-forbindelsen fejlede. Indstillinger viser "Could not connect to <IP>" i stedet for "No connected devices".
- **Rettet: forbindelsen virkede ikke på Android.** Android blokerer ukrypteret `ws://`/`http://` som standard. Det er nu tilladt (`usesCleartextTraffic`). Scanningen virkede, fordi den bruger en rå TCP-forbindelse.
- iOS: tilladelse til lokalt netværk (`NSAllowsLocalNetworking` og `NSLocalNetworkUsageDescription`).
- Appen står først som forbundet, når WebSocket-forbindelsen faktisk er oppe (højst 10 sekunder). Før stod den som forbundet med det samme.
- Når du skifter robot, lukkes den gamle forbindelse først, så den ikke kan afbryde den nye.
- Ugyldige beskeder fra robotten får ikke længere appen til at fejle.

## 2026-10-16 – Build (GitHub Actions)

- Workflowet bygger **kun Android**. iOS-jobbet er fjernet.
- **Rettet: buildet fejlede uden keystore.** Hvis secret'en `KEYSTORE_BASE64` mangler, bruges debug-signering.
- Opdateringstjekket peger på repoet `Ragsie/app_test` i stedet for `OmniMow_App`. Repoet er privat, så tjekket giver 404 uden login.

## 2026-10-09 – Kamerakalibrering i stedet for GPS

- Robotten har ikke længere GPS. Den finder sin position med stereokameraerne (visuel SLAM).
- Backenden er flyttet til port 9000. Rosbridge bruger fortsat 8000.
- Statussen for GPS/RTK er erstattet af status for kamerakalibreringen: et statusmærke på dashboardet med "Recalibrate", et felt på metrics-skærmen og notifikationer.
- Start/pause, hjem og den nye "Map lawn" (automatisk kortlægning af kanten) bruger backendens REST-adresser og viser dens svar.
- Missionens tilstand og fremskridt kommer fra mowing_control.
- Kortet viser plænezoner, rute og retning på SLAM-kortet.
- Kodestil: alle `if`-sætninger har nu klammer (lint-reglen `curly_braces_in_flow_control_structures`).
