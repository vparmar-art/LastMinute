# API Configuration Guide

## For Local Development

The API URL in `lib/secrets.dart` needs to be configured based on where you're running the app:

### Android Emulator
```dart
static const String apiBaseUrl = 'http://10.0.2.2:8000/api';
static const String wsBaseUrl = 'ws://10.0.2.2:8000/ws';
```

### iOS Simulator
```dart
static const String apiBaseUrl = 'http://localhost:8000/api';
static const String wsBaseUrl = 'ws://localhost:8000/ws';
```

### Physical Device (Android/iOS)
Use your machine's local IP address:
```dart
static const String apiBaseUrl = 'http://192.168.29.86:8000/api';  // Your current IP
static const String wsBaseUrl = 'ws://192.168.29.86:8000/ws';
```

To find your IP address:
- macOS/Linux: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- Windows: `ipconfig` (look for IPv4 Address)

## Quick Switch

1. Open `lib/secrets.dart`
2. Uncomment the appropriate line for your platform
3. Comment out the current one
4. Hot restart the app (not just hot reload)

