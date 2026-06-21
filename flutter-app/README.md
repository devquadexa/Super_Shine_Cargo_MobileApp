# Super Shine Cargo — Flutter Mobile App

Mobile frontend for the Super Shine Cargo shipping management system.

## Project Structure

```
lib/
├── main.dart                   # App entry point + routing
├── api/
│   ├── client.dart             # Dio HTTP client with JWT interceptor
│   └── auth_service.dart       # Auth API calls (login, getMe)
├── models/
│   └── user.dart               # User model
├── providers/
│   └── auth_provider.dart      # Auth state (ChangeNotifier)
└── screens/
    ├── login_screen.dart       # Login page
    └── dashboard_screen.dart   # Dashboard with stats cards
```

## Backend Connection

The app connects to the backend at `http://10.0.2.2:5000/api`.

- `10.0.2.2` is the Android emulator's alias for the host machine's `localhost`
- Make sure `backend-api` is running on port 5000 before launching the app
- For a physical device, change `_baseUrl` in `lib/api/client.dart` to your machine's local IP

## Running

1. Start the backend: `cd backend-api && npm run dev`
2. Open `flutter-app/` in Android Studio
3. Start an Android emulator from Device Manager
4. Run the app with `Shift+F10` or the ▶ button

## Dependencies

| Package | Purpose |
|---|---|
| `dio` | HTTP client |
| `flutter_secure_storage` | JWT token storage |
| `provider` | State management |
