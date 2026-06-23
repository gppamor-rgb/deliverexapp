# Deliverex

A delivery management platform with fleet dispatch, real-time tracking, OCR documentation, and a built-in assistant chatbot.

- **Web App:** [https://deliverexapp.com](https://deliverexapp.com)
- **Mobile App:** Built with Flutter (this repo)
- **Download APK:** [Deliverexapp.apk](Deliverexapp.apk)


## Features

- **Customer Portal** — sign up, manage deliveries, track orders
- **Driver App** — job assignments, status updates, proof of delivery, offline mode with background sync
- **Real-time Tracking** — track deliveries with ETA and activity logs
- **OCR Documentation** — scan and process delivery documents
- **Deliverex Assistant** — AI-powered chatbot for support and tracking

## Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Laravel (PHP)
- **HTTP Client:** Dio
- **State Management:** ChangeNotifier + ListenableBuilder
- **Offline Storage:** SQLite

## Getting Started

```bash
git clone https://github.com/gppamor-rgb/deliverexapp.git
cd deliverex
flutter pub get
flutter run
```

## Project Structure

```
lib/
├── app/              # App entry point
├── core/             # Colors, sizes, theme, helpers
├── database/         # SQLite helpers
├── models/           # Data models
├── providers/        # State management
├── repositories/     # Data access layer
├── screens/          # UI screens
├── services/         # API clients
└── widgets/          # Reusable widgets
```

## License

All rights reserved.
