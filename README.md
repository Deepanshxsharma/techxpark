# TechXPark 🚗

![TechXPark Banner](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) ![Firebase](https://img.shields.io/badge/firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)

TechXPark is a production-ready, feature-rich parking management mobile application built with Flutter and Firebase. It provides a seamless experience for users to find, book, and manage parking slots in real-time.

## ✨ Features

- **🔐 Authentication**: Secure user login and registration powered by Firebase Auth.
- **📅 Real-time Booking System**: Interactive parking slot selection with real-time overlap protection and double-booking prevention using Firestore transactions.
- **💬 Live Messaging**: Built-in real-time chat supporting user-to-user and user-to-admin support channels.
- **🔔 Push Notifications**: Stay updated on booking statuses and unread messages.
- **🏢 Parking Slot Management**: Visual, bird's-eye view mapping of parking floors and slots with dynamic availability indicators.
- **🎨 Material 3 UI**: A highly polished, consistent, and beautiful design system utilizing reusable, modular widgets.

## 🏗️ Architecture & Tech Stack

- **Frontend**: Flutter & Dart (Material 3 Design System)
- **Backend & Database**: Firebase Cloud Firestore (NoSQL)
- **Authentication**: Firebase Authentication
- **State Management**: Stream-based reactive architecture
- **Security**: Robust Firestore Security Rules restricting unauthorized access and enforcing business logic.

### Folder Structure
```text
lib/
├── models/         # Data models (User, Booking, Conversation, Message)
├── presentation/   # UI Layer (Screens & Views grouped by feature)
├── services/       # Business Logic & Firebase Integration Services
├── theme/          # App-wide theming (Colors, Typography, Spacing)
└── widgets/        # Reusable, shared UI components
```

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
   cd techxpark
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/).
   - Enable Authentication (Email/Password), Firestore, and Storage.
   - Run `flutterfire configure` to generate your `firebase_options.dart` file.
   - Deploy the provided `firestore.rules` to secure your database:
     ```bash
     firebase deploy --only firestore:rules
     ```

4. **Run the App**
   ```bash
   flutter run
   ```

## 🔮 Future Improvements

- [ ] Add Stripe payment gateway integration.
- [ ] Implement Google Maps for parking lot navigation.
- [ ] Add QR code generation for gate entry scanning.
- [ ] Implement automated CI/CD pipelines via GitHub Actions.

## 🤝 Contributing

Contributions are welcome! Please read the `CONTRIBUTING.md` for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
