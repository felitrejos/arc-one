# Arc One

A personal finance management app for iOS that helps you track investments, stocks, and cryptocurrency portfolios with real-time market data and comprehensive analytics.

## Features

### Portfolio Management
- Track multiple investment holdings (stocks and crypto)
- Add and manage investments with purchase details
- View detailed investment performance metrics
- Real-time portfolio valuation and history tracking
- Interactive charts showing portfolio performance over time

### Authentication & Security
- Firebase Authentication with multiple sign-in methods:
  - Email/Password
  - Google OAuth
- Face ID biometric authentication for enhanced security
- Secure user profile management

### Profile & Settings
- Customizable user profiles
- Account information management

## Architecture

The app follows a feature-based architecture with clean separation of concerns:

```
Arc One/
├── Features/
│   ├── Authentication/     # Login, signup, and biometrics
│   ├── Portfolio/          # Investment tracking and management
│   ├── Profile/            # User profile and settings
│   └── Crypto/             # Cryptocurrency features
├── Utilities/              # Shared formatters and extensions
└── GoogleService-Info.plist
```

Each feature module contains:
- **UI**: View controllers and custom cells
- **Models**: Data models and view models
- **Services**: Business logic and API integration
- **Presentation**: Data sources and coordinators

## Technologies

- **Firebase**: Authentication, Firestore database
- **UIKit**: Native iOS UI framework
- **Google Sign-In**: Third-party authentication

## Requirements

- iOS 13.0+
- Xcode 12.0+
- Firebase project with:
  - Authentication enabled (Google providers)
  - Firestore database

## Getting Started

1. Clone the repository
2. Ensure `GoogleService-Info.plist` is properly configured for your Firebase project
3. Open `Arc One.xcodeproj` in Xcode
4. Build and run (⌘ + R)

## Authors

Felipe Trejos and Paul Adrian Pupaza
