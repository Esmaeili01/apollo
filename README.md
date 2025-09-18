# Apollo 🚀

A modern, cross-platform messaging application built with Flutter and powered by Supabase.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-181818?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)

## 📱 About

Apollo is a comprehensive messaging application that provides seamless communication across all major platforms. Built with Flutter's cross-platform capabilities, it offers a native experience on Android, iOS, Web, Windows, Linux, and macOS.

## ✨ Features

### Core Messaging
- 💬 **Private Chat**: One-on-one messaging with real-time delivery
- 👥 **Group Chat**: Multi-user group conversations
- 🎙️ **Voice Messages**: Record and send voice notes
- 📎 **File Sharing**: Share documents, images, and media files
- ✏️ **Message Editing**: Edit and update sent messages
- 💬 **Reply System**: Reply to specific messages in conversations
- ✅ **Message Status**: Read receipts and delivery indicators

### User Management
- 🔐 **Secure Authentication**: Login and signup with Supabase Auth
- 👤 **User Profiles**: Complete profile management system
- 📞 **Contacts Management**: Add and manage contacts
- 🟢 **Online Status**: Real-time online/offline status tracking
- 🔔 **Smart Notifications**: Customizable notification preferences

### Cross-Platform Support
- 🤖 **Android**: Native Android experience
- 🍎 **iOS**: Native iOS experience  
- 🌐 **Web**: Progressive Web App
- 🖥️ **Windows**: Native desktop app
- 🐧 **Linux**: Native Linux support
- 🍎 **macOS**: Native macOS app

## 🛠️ Tech Stack

- **Frontend**: Flutter SDK 3.8.1+
- **Backend**: Supabase (PostgreSQL, Real-time, Auth, Storage)
- **State Management**: Riverpod
- **Audio**: Flutter Sound, Just Audio
- **Images**: Cached Network Image, Image Picker
- **UI Components**: Material Design, Cupertino Icons

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Visual Studio / Xcode (for desktop development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Esmaeili01/apollo.git
   cd apollo
   ```
   or
   ```bash
   git clone https://github.com/sobhan051/apollo.git
   ```
   then 
   ```bash
   cd apollo
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a Supabase project at [supabase.com](https://supabase.com)
   - Update the Supabase credentials in `lib/main.dart`:
     ```dart
     const supabaseUrl = 'YOUR_SUPABASE_URL';
     const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
     ```

4. **Run the application**
   ```bash
   # For development
   flutter run
   
   # For specific platforms
   flutter run -d chrome          # Web
   flutter run -d windows         # Windows
   flutter run -d macos           # macOS
   flutter run -d linux           # Linux
   ```

### Database Setup

Set up your Supabase database with the following tables:
- `profiles` - User profile information
- `messages` - Chat messages
- `contacts` - User contacts and relationships
- `groups` - Group chat information

## 📁 Project Structure

```
apollo/
├── 📱 lib/                     # Main source code
│   ├── main.dart              # App entry point
│   ├── pages/                 # UI screens
│   │   ├── splash.dart
│   │   ├── login.dart
│   │   ├── signup.dart
│   │   ├── home.dart
│   │   ├── settings.dart
│   │   ├── private_chat/      # Private messaging
│   │   └── group_chat/        # Group messaging
│   └── utils/                 # Helper functions
├── 🤖 android/                # Android-specific code
├── 🍎 ios/                    # iOS-specific code
├── 🌐 web/                    # Web-specific code
├── 🖥️ windows/               # Windows-specific code
├── 🐧 linux/                 # Linux-specific code
├── 🍎 macos/                 # macOS-specific code
└── 🧪 test/                  # Test files
```

## 🔧 Configuration

### Development Environment

The project includes configurations for:
- **VS Code**: `.vscode/settings.json`
- **Cursor**: `.cursor/mcp.json`
- **IntelliJ/Android Studio**: `.idea/` folder

### Platform-Specific Setup

#### Web
- Supports PWA installation
- Browser notifications for messages
- Optimized for all modern browsers

#### Desktop (Windows/macOS/Linux)
- Native file system integration
- System tray support
- Platform-specific UI adaptations

#### Mobile (Android/iOS)
- Push notifications
- Background app refresh
- Native media integration

## 🧪 Testing

Run tests with:
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Widget tests
flutter test test/widget_test.dart
```

## 🔨 Building

### Development Build
```bash
flutter build apk --debug      # Android Debug
flutter build ios --debug      # iOS Debug
flutter build web              # Web
```

### Release Build
```bash
flutter build apk --release    # Android Release
flutter build ios --release    # iOS Release
flutter build web --release    # Web Release
flutter build windows          # Windows
flutter build macos            # macOS
flutter build linux            # Linux
```

## 📦 Dependencies

### Core Dependencies
- `supabase_flutter` - Backend services
- `flutter_riverpod` - State management
- `image_picker` - Image selection
- `file_picker` - File selection
- `flutter_sound` - Audio recording
- `just_audio` - Audio playback
- `cached_network_image` - Image caching
- `emoji_picker_flutter` - Emoji support

### Development Dependencies
- `flutter_test` - Testing framework
- `flutter_lints` - Code analysis

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Dart/Flutter style guidelines
- Use meaningful variable names
- Add comments for complex logic
- Ensure all tests pass

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/Esmaeili01/apollo/issues) page
2. Create a new issue with detailed information
3. Join our community discussions

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Supabase team for the powerful backend
- Open source community for the packages used

## 📞 Contact

- **Developer**: Your Name
- **Email**: your.email@example.com
- **Project Link**: [https://github.com/Esmaeili01/apollo](https://github.com/Esmaeili01/apollo)

---

<div align="center">
  <strong>Built with ❤️ using Flutter</strong>
</div>