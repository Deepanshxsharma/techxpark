# TechXPark 🚗

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firestore](https://img.shields.io/badge/Cloud_Firestore-039BE5?style=for-the-badge&logo=firebase&logoColor=white)

> A production-ready, feature-rich smart parking management application built with Flutter and Firebase. TechXPark enables users to discover, book, and manage parking slots in real-time with a premium, polished user experience.

---

## ✨ Features

| Category | Highlights |
|---|---|
| 🔐 **Authentication** | Email/Password, Google & Apple Sign-In via Firebase Auth |
| 📅 **Smart Booking** | Real-time slot selection with overlap protection and double-booking prevention using Firestore transactions |
| 🗺️ **Interactive Map** | Discover nearby parking locations on a live dashboard map |
| 🚗 **My Garage** | Manage your vehicles with real-time RapidAPI lookup and instant booking integration |
| 💬 **Live Messaging** | Real-time chat with user-to-user and admin support channels |
| 🔔 **Notifications** | Push notifications for booking statuses, messages, and reminders |
| 🏢 **Parking Overview** | Visual floor-by-floor parking grid with dynamic availability indicators |
| 🎫 **Digital Tickets** | Interactive parking tickets with timers, QR codes, and extend/cancel options |
| 👤 **Profile Management** | Edit profile, upload photos, and manage account settings |
| 🛡️ **Admin Panel** | Full admin dashboard for managing users, bookings, and parking locations |
| 📺 **Owner Panel** | Parking lot owner dashboard for managing their facilities |
| 🎨 **Premium UI/UX** | Apple/Tesla-inspired aesthetic, Stitch design system integration, and fluid micro-animations |

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter & Dart (Material 3) |
| **Backend** | Firebase Cloud Firestore (NoSQL) |
| **Auth** | Firebase Authentication |
| **Storage** | Firebase Cloud Storage |
| **Notifications** | Firebase Cloud Messaging (FCM) |
| **State** | Stream-based reactive architecture |
| **Security** | Firestore Security Rules |
| **Hosting** | Firebase Hosting (web panels) |

---

## 📁 Project Structure

```text
lib/
├── models/           # Data models (User, Booking, Conversation, Message)
├── presentation/     # UI Layer — screens grouped by feature
│   ├── admin/        #   Admin dashboard & management screens
│   ├── auth/         #   Login, Signup, Auth wrapper
│   ├── booking/      #   Booking flow, tickets, timers
│   ├── map/          #   Dashboard map, search, parking discovery
│   ├── messages/     #   Chat & support messaging
│   ├── notifications/#   Notification center
│   ├── profile/      #   Profile, edit profile
│   └── vehicle/      #   Garage / vehicle management
├── services/         # Business logic & Firebase service layer
│   ├── booking_service.dart
│   ├── abuse_monitor.dart
│   └── google_auth_service.dart
├── theme/            # Design system tokens
│   ├── app_colors.dart
│   ├── app_text_styles.dart
│   └── app_spacing.dart
└── widgets/          # Reusable shared components
    ├── app_button.dart
    ├── app_card.dart
    └── app_text_field.dart
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>= 3.0.0`
- Dart SDK `>= 3.0.0`
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project with Firestore, Auth, and Storage enabled

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Deepanshxsharma/techxpark.git
   cd techxpark
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase setup**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/)
   - Enable **Authentication** (Email/Password + Google)
   - Enable **Cloud Firestore**
   - Enable **Cloud Storage**
   - Run FlutterFire CLI to configure:
     ```bash
     flutterfire configure
     ```
   - Deploy Firestore security rules:
     ```bash
     firebase deploy --only firestore:rules
     ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🔒 Security

- All booking operations use **Firestore transactions** to prevent race conditions and double bookings.
- **Abuse monitoring** tracks failed booking attempts and blocks suspicious activity.
- Firestore Security Rules enforce role-based access control (`customer`, `owner`, `admin`).
- Sensitive files (`google-services.json`, keystores, `.env`) are excluded via `.gitignore`.

---

## 🔮 Roadmap

- [ ] Stripe payment gateway integration
- [ ] Google Maps navigation to parking lots
- [ ] QR code scanning for gate entry
- [ ] CI/CD pipeline via GitHub Actions
- [ ] Parking lot analytics dashboard
- [ ] Multi-language support (i18n)

---

## 🤝 Contributing

Contributions are welcome! Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

---

## 📄 License

This project is licensed under the MIT License — see the [`LICENSE`](LICENSE) file for details.

---

<p align="center">
  Built with ❤️ by <a href="https://github.com/Deepanshxsharma">Deepansh Sharma</a>
</p>
