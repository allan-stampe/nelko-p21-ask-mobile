# Hent den konkrete installationsfejl fra Galaxy S22

Det er ikke nødvendigt at gætte ud fra »Appen blev ikke installeret«. Formålet her er at registrere telefonens egen fejl og sammenligne den grafiske installation med ADB-installation. APK-kontrollen og emulatorresultaterne står i [installationsrapporten](INSTALLATION-AUDIT-v0.0.1.md).

## Klargøring på Windows

Hent [Android SDK Platform-Tools til Windows fra Google](https://developer.android.com/tools/releases/platform-tools), pak ZIP-filen ud, og åbn PowerShell i mappen `platform-tools`. Aktivér udviklerindstillinger og USB-fejlretning på telefonen, tilslut USB og godkend computerens USB-fejlretningsprompt på telefonen.

```powershell
.\adb.exe devices -l
```

Telefonen skal stå som `device`, ikke `unauthorized`. Hvis flere enheder vises, skal kommandoerne nedenfor bruge `-s TELEFONENS_SERIENUMMER` efter `adb.exe`. Del ikke serienummeret offentligt.

## Kontrollér filen

Hent den direkte v0.0.1-APK fra GitHub på computeren, og angiv dens fulde sti:

```powershell
$apk = 'C:\sti\til\NELKO-P21-ASK-Mobile-v0.0.1-experimental.apk'
(Get-FileHash -Algorithm SHA256 -LiteralPath $apk).Hash
```

Forventet SHA-256:

```text
7b3957e467b8b7c2299dcc0b00e35b44c68996cfc7a7ef668ddb2d425199f24d
```

Stop og hent filen igen, hvis den ikke matcher. Telefonens egen download kan læses uden ændringer med følgende kommando, hvis filen ligger præcis dér; tilpas stien ved et andet filnavn:

```powershell
.\adb.exe shell sha256sum /sdcard/Download/NELKO-P21-ASK-Mobile-v0.0.1-experimental.apk
```

## Registrér først den grafiske fejl

Mens appen stadig ikke er installeret:

```powershell
.\adb.exe logcat -c
```

Prøv nu APK-installationen på telefonens skærm igen. Umiddelbart efter fejlbeskeden:

```powershell
.\adb.exe logcat -d -v threadtime > .\ask-ui-install-logcat.txt
```

## Registrér derefter ADB-resultatet

```powershell
.\adb.exe logcat -c
.\adb.exe install --no-streaming $apk 2>&1 | Tee-Object -FilePath .\ask-adb-install-result.txt
.\adb.exe logcat -d -v threadtime > .\ask-adb-install-logcat.txt
.\adb.exe shell getprop ro.build.version.sdk
.\adb.exe shell getprop ro.product.cpu.abilist
.\adb.exe shell getconf PAGE_SIZE
```

**ADB-kommandoen forsøger en rigtig installation af appen.** Den hverken afinstallerer en eksisterende app, bruger test-/SDK-undtagelser eller ændrer telefonens installationspolitik. Hvis den giver `Success`, er appen installeret via ADB; det forklarer ikke i sig selv, hvorfor det grafiske forsøg blev afvist. Hvis den fejler, er hele linjen `Failure [...]` vigtig. Notér også, om telefonen viste en konkret sikkerhedsbesked.

Start med kun at dele den korte `Success`/`Failure [...]`-tekst og relevante installationslinjer. Du kan finde kandidater lokalt med:

```powershell
Select-String -Path .\ask-*-logcat.txt -Pattern 'INSTALL_FAILED|INSTALL_PARSE_FAILED|PackageInstaller|PackageManager|verifier|blocked'
```

Logcat kan indeholde oplysninger fra andre apps. Gennemse og redigér private oplysninger før deling; send ikke ukritisk hele telefonens log offentligt. Der er ikke påvist en årsag, som begrunder at slå sikkerhedsfunktioner fra.
