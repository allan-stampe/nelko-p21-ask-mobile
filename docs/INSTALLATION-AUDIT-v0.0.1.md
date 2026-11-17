# Installationstest af v0.0.1 — 17. november 2026

**Konklusion: Den originale release-APK kan installeres og startes på Android 12 og Android 16 i emulator. Årsagen til afslaget på Galaxy S22 er endnu ikke fastslået. Ingen ny APK er udgivet, da undersøgelsen ikke har påvist en fejl, som begrunder en rettelse.**

Telefonens oplysninger fra ejeren: Samsung Galaxy S22, Android 16, One UI 8.0, ingen tidligere ASK Mobile-installation. Ejeren brugte den direkte APK fra GitHub Release v0.0.1. Beskeden »Appen blev ikke installeret« indeholder ikke den nødvendige PackageManager-fejlkode.

## Undersøgt fil

Den eksisterende offentlige release er bevaret uændret. Alle prøver bruger [den originale APK](https://github.com/allan-stampe/nelko-p21-ask-mobile/releases/download/v0.0.1/NELKO-P21-ASK-Mobile-v0.0.1-experimental.apk), hentet direkte fra GitHub, uden genpakning, ny signering eller genkompilering.

- Filstørrelse: **48.647.440 bytes**.
- SHA-256: `7b3957e467b8b7c2299dcc0b00e35b44c68996cfc7a7ef668ddb2d425199f24d`.
- Hashen matcher release-checksummen og GitHubs asset-digest. Det verificerer den hentede referencefil, ikke automatisk kopien på telefonen.
- ZIP CRC for alle filer: OK; ingen dublerede ZIP-navne.

## Signatur og certifikat

Android SDK Build Tools 36.0.0 `apksigner verify --verbose --print-certs` giver **Verifies**, én signer og gyldig APK Signature Scheme **v2**. V1, v3, v3.1, v4 og SourceStamp er ikke til stede. V2 understøttes fra Android 7 og er tilstrækkelig for denne APK's minimum Android 8; de øvrige ordninger er ikke alle obligatoriske.

Certifikatet er selvsigneret: `CN=Android Debug, O=Android, C=US`, RSA 2048 bit. SHA-256-fingerprint:

```text
21c8ff4881b06b703dcec9bbdc6aa7fff7811d4f255b0d695f69209f2b12371b
```

Gyldighed: 16. november 2026 kl. 18.09.38 til 8. november 2056 kl. 18.09.38, dansk normaltid (CET). Det matcher den offentliggjorte certifikatfil. Certifikatets offentlige del og værktøjsoutput er gemt som [evidens](evidence/v0.0.1-installation/signature.txt). Ingen privat nøgle er gemt her.

Dette er fortsat en eksperimentel APK med testnøgle, ikke en stabil produktionssignatur. Den er en release-variant: manifestet har hverken `testOnly=true` eller `debuggable=true`. Emulatorerne accepterede den med almindelig `adb install`, **uden `-t`**. Undersøgelsen giver derfor ikke belæg for at udpege testcertifikatet som årsag til S22-afslaget. Midlertidige nøgler kan give opdateringskonflikt mellem builds, men ejeren oplyser, at appen aldrig har været installeret på telefonen.

## Manifest og Android-krav

Det kompilerede binære manifest er læst med `aapt2 dump xmltree` og i CI også `apkanalyzer manifest print`.

| Felt | Faktisk værdi |
|---|---|
| Pakke | `dk.ask.nelko_p21_ask_mobile` |
| versionName / versionCode | `0.0.1` / `1` |
| minSdkVersion | `26` — Android 8.0 |
| targetSdkVersion / compileSdkVersion | `36` — Android 16 |
| Launcher | `.MainActivity`, `exported=true` |
| Native biblioteker | `extractNativeLibs=false` |
| App-type | Selvstændig universal APK; intet split-installationskrav |
| Internet | Ingen INTERNET-tilladelse |
| Backup | `allowBackup=false` |

Der er ingen maxSdkVersion på selve appen, ingen sharedUserId og ingen krævet AndroidX window-udvidelse. Legacy Bluetooth/lokationstilladelser er begrænset til API 30; Android 12+ bruger SCAN/CONNECT. Det er tilladelsesregler for brug, ikke en påvist installationsblokering. Target 36 er ikke et for gammelt target for Android 16. [Det faktiske manifest](evidence/v0.0.1-installation/manifest-tree.txt) er bevaret.

## ARM64 og sidejustering

APK'en indeholder `libapp.so` og `libflutter.so` for **arm64-v8a**, armeabi-v7a og x86_64. ARM64-filerne har korrekte ELF64/AArch64-headere (`e_machine=183`). Begge ARM64-filers LOAD-segmenter bruger `p_align=0x10000` (64 KB), og native ZIP-payloads er ukomprimerede og 16 KB-justerede. `zipalign -c -P 16 -v 4` består.

Der er dermed ikke fundet manglende ARM64-filer eller den kontrollerede type 4/16 KB-justeringsfejl. Dette er statisk kontrol af ARM64, **ikke en udført ARM64-runtime- eller Samsung-test**.

## Udført installation og start

[CI-kørsel med reproducerbare kontroller](https://github.com/allan-stampe/nelko-p21-ask-mobile/actions/runs/44038930720). Emulatorerne var friske Google APIs x86_64-systemer uden ASK-pakken installeret. Begge havde 4096 bytes sidestørrelse. APK'en blev checksumkontrolleret i hver jobkørsel.

```sh
adb install --no-streaming original-release.apk
adb shell am start -W -n dk.ask.nelko_p21_ask_mobile/.MainActivity
```

Ingen `-t`, lav-target-undtagelse, genpakning eller ny signering blev brugt.

| Emulator | Installation | Start |
|---|---|---|
| Android 12, API 31 | `Success` | `Status: ok`, COLD |
| Android 16, API 36 | `Success` | `Status: ok`, COLD |

App-processen kørte efter opstart. De undersøgte launch-logs indeholdt ingen `FATAL EXCEPTION` eller Flutter `Unhandled Exception`. [Android 16-skærmbillede](evidence/v0.0.1-installation/api-36/launched.png), [API 36-installationsoutput](evidence/v0.0.1-installation/api-36/install.txt) og [API 31-installationsoutput](evidence/v0.0.1-installation/api-31/install.txt) er gemt. De fulde logfiler og emulatoroplysninger findes i CI-artifacts.

ADB-installation i en Google-emulator efterprøver Androids pakkeinstallation, men efterligner ikke Samsungs grafiske installationsforløb eller telefonens sikkerhedspolitikker. Prøven validerer heller ikke Bluetooth eller fysisk udskrivning.

## Hvad mangler for at fastslå S22-årsagen?

Den konkrete installationsfejlkode og relevante PackageInstaller/PackageManager-loglinjer fra **den berørte telefon**. Der er endnu ingen evidens for at vælge en bestemt telefonindstilling eller APK-ændring som løsning. [Vejledningen nedenfor](S22-INSTALL-DIAGNOSTICS.md) beskriver indsamlingen. Kontrol af telefonens egen filhash kan også afklare, om dens download matcher referencefilen.

Ny testversion afventer en påvist fejl eller en begrundet ændring. Windows-projektet, den udgivne APK og Bluetooth-koden er uændrede.
