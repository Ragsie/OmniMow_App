# Changelog – OmniMow app

Alle ændringer i appen. Nyeste øverst.

## 2026-11-24 – Ny signeringsnøgle (Android)

- **Appen signeres med en ny nøgle.** Den gamle er skiftet ud af sikkerhedshensyn. Android installerer ikke en opdatering, der er signeret med en anden nøgle ("App not installed"), så **afinstallér appen én gang** og installér den nye. Gemte mowers og indstillinger skal sættes op igen. iOS-appen er ikke berørt.
- Buildet bruger en fast Flutter-version (3.50.1) og Android Gradle Plugin 9.1.1. Før kunne en ny Flutter-version stoppe buildet, uden at koden var ændret.

## 2026-10-31 – Build i private repoer

- I et privat repo (fx en privat fork) bygger et push til `main` ikke længere appen af sig selv: start buildet under *Actions → OmniMow Android & iOS Build → Run workflow* eller med et `v*`-tag. Så bruges der ingen Actions-minutter (iOS-buildet kører på macOS, der tæller ti gange). Offentlige repoer bygger stadig hvert push.

## 2026-10-28 – Opdateringer og signering

- **Appen opdaterer sig fra det GitHub-repo, den er bygget i.** Build-workflowet giver repoet med (`--dart-define=UPDATE_REPO=...`), så et build fra en fork eller et udviklings-repo henter sine opdateringer derfra. Builds uden det bruger `Ragsie/OmniMow_App`.
- **Alle builds signeres med appens egen nøgle.** Manglede secret'en `KEYSTORE_BASE64`, blev APK'en signeret med en ny debug-nøgle ved hvert build, og Android nægtede at installere den som opdatering ("App not installed"). Nu stopper buildet uden nøglen, og workflowet tjekker, at APK'en er signeret med samme certifikat som alle releases (`android/app/signing-cert.sha256`).

## 2026-10-27 – Tidsplan, regnforsinkelse og notifikationer

- **Tidsplanen viser den, der er gemt på mower'en.** Skærmen startede altid med 09:00, man/ons/fre og 4 timer og overskrev mower'ens tidsplan, når man gemte. Nu læses den fra mower'ens status (`system.schedule`).
- **Tidsplanen kan slås fra** med *Mow by schedule*. Før sendte appen altid `"enabled": true`.
- *Save Schedule* viser mower'ens svar og lukker først, når tidsplanen er gemt. Før stod der "saved" uanset svaret.
- **Regnforsinkelsen følger mower'ens egen tørretimer** (`system.rain_delay`), så banneret og "N min left" passer med, hvornår mower'en må klippe igen. Med nyere mower-software vises også mower'ens tørretid i indstillingerne (før 15 min i appen mod 2 timer på mower'en). Ældre mower-software: appens egen nedtælling som før.
- Skyderen for regnforsinkelse sender først værdien, når den slippes (før én forespørgsel pr. trin).
- **Notifikationerne "Docking Updates" og "Charging Status" virker.** De ventede på mower-tilstand 2 og 3, som ESP32'en aldrig sender; nu bruges missionens tilstand (`RETURNING`, `CHARGING`).
- Opdateringsdialogen siger, at mower'en genstarter efter en opdatering.
- *Om & Anerkendelser* hedder nu *About & Credits* som resten af appen.
- README: rettet CI- og release-badge, port 9000 (ikke 8000), ingen GPS/RTK, døde links erstattet af wikierne.
- `.gitignore`-filer er tilføjet, og en build-rapport (`android/build/`), der var kommet med i git, er fjernet.

## 2026-10-24 – Ladestationen på kortet

- Kortet tegner ladestationen, hvor mower'en selv har gemt den (`map.dock`), og Nerd Metrics viser robottens og stationens position samt afstand og retning til stationen. Kræver mower-software, der sender `map`.

## 2026-10-23 – Opdatering af mower-softwaren

- **Appen fortæller, når der er en ny version af mower-softwaren.** Mower'en tjekker selv GitHub for en ny release hver time og sender det til appen (`software_update` i status). Appen viser en notifikation én gang pr. release og et opdateringsikon øverst på dashboardet.
- **Opdater mower'en fra appen.** Under *Indstillinger → Mower Software* ser du den installerede version, hvad der er nyt, og kan trykke *Install update* (`POST /api/software/update`). Mower'en skal stå stille eller være i laderen. Den bygger og genstarter sine services, og appen forbinder igen af sig selv og giver besked, når opdateringen er færdig eller fejlede.
- *Check now* beder mower'en tjekke med det samme (`POST /api/software/check`).
- Ny notifikationsindstilling: *Mower Software Updates*.
- Kræver OmniMow `v2026.10.23-1` eller nyere på mower'en.

## 2026-10-22 – Live video

- **Livevideoen virker nu med mower'ens nye `video_stream`-service** (`ws://<ip>:8889/webrtc`). Appen beder nu om at modtage video, når den laver sit WebRTC-offer. Før indeholdt offeret ingen video-sektion, så mower'en kunne ikke sende billede.

## 2026-10-16 – Appens navn og iOS

- Appen hedder **OmniMow** med app-id'et **`com.omnimow.app`**, også på iOS. APK-filer, releases og workflowet hedder også OmniMow.
- Workflowet bygger **både Android (APK) og iOS** (usigneret zip til Sideloadly/AltStore).

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

- **Rettet: buildet fejlede uden keystore.** Hvis secret'en `KEYSTORE_BASE64` mangler, bruges debug-signering.

## 2026-10-09 – Kamerakalibrering i stedet for GPS

- Robotten har ikke længere GPS. Den finder sin position med stereokameraerne (visuel SLAM).
- Backenden er flyttet til port 9000. Rosbridge bruger fortsat 8000.
- Statussen for GPS/RTK er erstattet af status for kamerakalibreringen: et statusmærke på dashboardet med "Recalibrate", et felt på metrics-skærmen og notifikationer.
- Start/pause, hjem og den nye "Map lawn" (automatisk kortlægning af kanten) bruger backendens REST-adresser og viser dens svar.
- Missionens tilstand og fremskridt kommer fra mowing_control.
- Kortet viser plænezoner, rute og retning på SLAM-kortet.
- Kodestil: alle `if`-sætninger har nu klammer (lint-reglen `curly_braces_in_flow_control_structures`).
