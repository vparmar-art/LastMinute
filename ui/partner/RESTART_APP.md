# ⚠️ IMPORTANT: Restart Required

## The Problem
After changing `secrets.dart`, the app needs a **full restart**, not just hot reload.

Const values in Dart are compiled at build time, so hot reload won't pick up changes to:
- `static const String apiBaseUrl`
- `static const String wsBaseUrl`

## Solutions

### Option 1: Full Restart (Recommended)
1. **Stop the app completely** (close it or use the stop button)
2. **Run it again**: `flutter run`

### Option 2: Hot Restart
- In VS Code: Press `Ctrl+Shift+F5` (Windows/Linux) or `Cmd+Shift+F5` (Mac)
- In Android Studio: Click the "Hot Restart" button (circular arrow icon)
- Or use command: Press `R` in the terminal where `flutter run` is active

### Option 3: Clean Build (If still not working)
```bash
cd ui/partner
flutter clean
flutter pub get
flutter run
```

## Verify It Worked
After restart, check the logs - you should see requests going to `10.0.2.2:8000` instead of `localhost:8000`.

