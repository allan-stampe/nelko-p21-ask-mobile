# NELKO P21 – ASK iOS Edition v0.0.3

**Tidlig iOS-udgave med fysisk bekræftet referenceprint. Ejeren har bekræftet installation, opstart, BLE og en udskrevet etiket med 0.0.2 på iPhone 11 Pro / oplyst iOS 27.2.1 og NELKO P21 (2026-11-24). 0.0.3 bevarer printerkoden.** Android remains version 0.0.3; the Windows project is untouched. This is not an App Store or TestFlight release.

Your printer. Your labels. Your data.  
No cloud. No account. Just print.

## Formål og status

Version 0.0.3 hedder **NELKO P21 – ASK iOS Edition**. Den forældede eksperimentelle advarsel og påstanden om ubekræftet print er rettet. [Hardwareanalysen](HARDWARE-2026-11-24.md) dokumenterer både syv-pakke-fejlen i 0.0.1 og det efterfølgende vellykkede print i 0.0.2: 181 TX-pakker / 3.513 bytes matcher hele Windows-referencejobbet, og ejeren bekræftede etiketten fysisk.

Dette er en tidlig udgave med referenceprint. Egne etikettekster og designer er endnu ikke implementeret. Bekræftelsen gælder den testede kombination, ikke alle iPhones og firmwarevarianter. iOS anvender lokal BLE via CoreBluetooth; Android-/Windows-koden bruger Classic SPP og er uændret.

Appen har dansk/engelsk brugerflade, BLE-søgning, valg/tilslutning, forbindelsesstatus, batteritest, Cancel Pause, ét referenceprint og lokal diagnoselog med UTC-tid, ASCII og HEX samt eksport. Ingen designer, automatisk genforbindelse, automatisk genudskrivning eller baggrundskommunikation i denne prototype. Udskrivning kræver et bevidst tryk. Loggen ligger i hukommelsen, slettes ved procesafslutning og begrænses til 500 poster/256 KiB; eksport bruger én midlertidig lokal fil.

## Installation fra Windows uden betalt udviklermedlemskab

IPA-filen er **usigneret**. Den kan ikke installeres ved blot at åbne den på telefonen. En lokal sideloading-app skal signere den med din egen Apple-konto. GitHub-buildet indeholder ingen Apple-konto, private nøgler eller provisioning profile.

1. Hent IPA og `SHA256SUMS.txt` fra [iOS-udgivelsen](https://github.com/allan-stampe/nelko-p21-ask-mobile/releases/tag/ios-v0.0.3). Kontrollér eventuelt filen i PowerShell med `Get-FileHash .\NELKO-P21-ASK-iOS-Edition-v0.0.3-unsigned.ipa -Algorithm SHA256`.
2. Hent **Sideloadly** fra [den officielle hjemmeside](https://sideloadly.io/). Følg sidens aktuelle Windows-krav til Apple iTunes og iCloud; brug de officielle Apple-downloads, som den henviser til. Ingen tredjeparts-IPA-sider er nødvendige.
3. Tilslut iPhone med USB. Lås telefonen op, og godkend “Stol på denne computer”, hvis den spørger. Kontrollér, at Windows/Apple-driverne og Sideloadly ser telefonen.
4. Vælg telefonen i Sideloadly, træk IPA-filen ind, og indtast din Apple-konto **lokalt i Sideloadly**. Følg Apples godkendelse/2FA. Del aldrig adgangskode eller koder i chat, GitHub eller Actions. Brug almindelig signering; appen behøver ingen tweaks, JIT eller ekstra rettigheder.
5. Klik Start. Følg telefonens anvisninger om udviklertilstand og tillid til udviklerprofilen. På nyere iOS findes de normalt under **Indstillinger → Anonymitet & sikkerhed → Udviklertilstand** (kan kræve genstart) og **Generelt → VPN og administration af enhed**. Menunavne kan variere. Genåbn appen efter godkendelse.
6. Hvis installationen fejler, gem den præcise fejl fra Sideloadly, uden personlige oplysninger. En kompileret IPA eller simulatorstart beviser ikke, at signering/installation virker på netop din telefon.

Ifølge [Sideloadlys FAQ](https://sideloadly.io/faq) kan en gratis Apple-konto bruges til almindelige iPhone-apps; signeringen gælder normalt **7 dage**, og højst **3 sideloadede apps** kan være aktive. Appen skal derefter signeres/installeres igen. Ejeren har gennemført denne installation på sin iPhone 11 Pro / oplyst iOS 27.2.1. Andre enheder/OS-versioner kan kræve separat afprøvning. Et medlemskab til 99 USD/år er således ikke nødvendigt for at forsøge denne testvej.

**Offline-kravet gælder selve printerappen.** Installation, Apple-signering og fornyelse kræver Apple-konto og netadgang i installationsværktøjet. Læs værktøjets aktuelle privatlivsoplysninger; dette projekt driver ikke den eksterne autentifikation. Printerappen har ingen login, server, HTTP-klient, cloud, reklamer, abonnementer eller telemetri. Normal printerbrug er lokal. iOS har ikke Androids `INTERNET`-manifesttilladelse. Systemets deleark kan tilbyde cloud-destinationer: vælg **Gem i Arkiver → På min iPhone**, hvis eksporten skal forblive lokal.

## Brug og afprøvning på andre enheder

1. Bekræft først, at appen installerer og åbner. Den benytter et standard Flutter-placeholderikon; endeligt iOS-ikon er ikke lavet.
2. Luk Windows-/Android-app og PowerShell-forbindelser til printeren. Sluk/tænd P21. Ifølge publicerede BLE-observationer annoncerer den muligvis kun BLE, mens Classic SPP er afbrudt.
3. Tryk **Giv Bluetooth-adgang**, godkend iOS-dialogen, og tryk **Søg BLE-enheder**. En søgning varer 10 sekunder. Listen er ufiltreret og kan vise andre enheder; vælg kun din egen printer. Enheds-id er iOS' UUID, ikke COM-port/MAC-adresse.
4. Vælg printeren og tilslut. Profilen skal have FF00, FF02 writeWithoutResponse og FF01 notify. Manglende profil eller notifikationsopsætning giver fejl/timeout og logges; forsøg ikke vilkårlige andre UUID'er.
5. Test batteri, så Cancel Pause. Ukendt batterisvar er ikke bevis på defekt printer; rå svardata er i loggen.
6. Med en 14×40 mm etiket: tryk testprint **én gang**, vent på resultatet, og fotografér etiketten. “API complete” betyder kun, at CoreBluetooth accepterede data, ikke at printeren skrev dem ud. Ved fejl sendes intet automatisk igen.
7. Eksportér loggen før appen lukkes. Gennemse id'er/indhold før deling. Notér telefon/OS, firmware hvis kendt, hvert trin og faktisk printresultat.

Appen afbryder forbindelsen, hvis den går i baggrunden. Genoptagelse udskriver aldrig automatisk. Manuel genforbindelse kræves. Ved `disconnect_pending` afventes iOS' gamle afbrydelse; hvis tilstanden ikke slipper, luk/genåbn appen. Ikke fysisk afprøvede firmwarevarianter kan kræve en anden BLE-profil eller flowkontrol; appen forsøger ikke andre protokoller automatisk.

Opdatér den eksisterende app med samme Apple-konto og automatiske bundle-id-indstilling i Sideloadly. Bundle-id er fortsat `dk.ask.nelkop21.ios`; den gamle app behøver normalt ikke slettes. Kontrollér **v0.0.3** i appen efter opdateringen. Ikonet er uændret.

## Byg og test

Isoleret Flutter-pakke med Flutter **3.38.5**, Dart 3.10.4, Swift 5, iOS minimum **15.0**, Xcode **26.2**, ARM64 device-build. En nyere OS-version kan køre et program bygget med et ældre SDK, men den konkrete telefon skal stadig afprøves. `macos-26` GitHub-hosted runner leverer Apple-buildmiljøet; ingen lokal Mac eller Proxmox-macOS kræves.

```sh
cd ios-prototype
flutter config --no-analytics
tool/bootstrap_ios.sh
flutter analyze --fatal-infos
flutter test
swiftc native/BLEFlow.swift swift-tests/main.swift -o work/ble-flow-tests
work/ble-flow-tests
flutter build ios --simulator --debug --no-pub
tool/simulator.sh
flutter build ios --release --no-codesign --no-pub
python3 tool/package.py
```

Bootstrap genererer standard iOS-projekt fra den fastlåste Flutter-version og indsætter de selvstændige Swift-filer. `ios/` er genereret og ikke committet. Ingen betalte capabilities, baggrundstilstande eller signing-hemmeligheder. Actions analyserer/tester Dart, tester ren Swift-flowkontrol, bygger/installerer/starter simulatorappen (iPhone 16e / iOS 26.2) og kontrollerer device-IPA'ens struktur, CRC, versionsnummer, deployment target og ARM64-binærfiler. Simulatoren beviser ikke BLE eller fysisk installation.

Root-Android-analyse udelukker denne selvstændige pakke; dens egen workflow analyserer den. Rodens Android-kilde, protokol og versionsnummer forbliver uændrede. Tags `ios-v*` er adskilt fra Androids `v*`.

Se [PROTOCOL.md](PROTOCOL.md), [CHANGELOG.md](CHANGELOG.md), [ROADMAP.md](ROADMAP.md) og [release-noter](RELEASE.md). Projektets MIT-licens gælder denne kode. Genbrugt MIT-protokol/logkode krediterer ASK-projektet og oprindelig udvikler **Tyler C**; den fulde oprindelige MIT-licens er bevaret i `../assets/licenses/Windows-MIT.txt` og bundlet som asset i IPA sammen med ASK-MIT og Go-fontens licens. AGPL-projektet nedenfor bruges alene som dokumentationskilde, uden kopieret/oversat kode. Flutter og eventuelle transitive afhængigheders licenser følger deres respektive pakker; Go-fonten i Android-pakken har sin bevarede BSD-licens.
