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