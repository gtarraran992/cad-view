# CAD View

App mobile per visualizzare file DWG/DXF e misurare distanze, delta X/Y e angoli direttamente sul cantiere.

## Funzionalità

- Apertura file DWG e DXF
- Visualizzazione disegni tecnici con zoom e pan
- Strumento misura: distanza, delta X, delta Y, angolo
- Snap automatico agli endpoint

## Stack tecnico

- Flutter (Android / iOS futuro)
- libdxfrw (C++) per parsing DWG/DXF via FFI
- Flutter CustomPainter per il rendering

## Sviluppo

```bash
flutter pub get
flutter run
```

## Requisiti

- Android 5.0+ (API 21)
- Flutter 3.27+

## Setup obbligatorio (ogni PC)

Dopo `flutter pub get`, modificare manualmente questi file nella cache pub:

### 1. flutter_plugin_android_lifecycle
```
%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_plugin_android_lifecycle-2.0.34\android\build.gradle.kts
```
Cambiare:
```kotlin
compileSdk = flutter.compileSdkVersion
```
in:
```kotlin
compileSdk = 36
```

### 2. file_picker
```
%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\file_picker-9.0.0\android\build.gradle
```
Cambiare `compileSdkVersion 34` in `compileSdkVersion 36`

## Note

- Le cartelle linux/, macos/, windows/ sono escluse — progetto Android only per ora
- Il file picker usa `FileType.any` perché il filtro per estensione .dwg non è supportato da tutti i dispositivi
