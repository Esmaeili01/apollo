# Apollo Messenger 🚀

A modern, cross-platform messaging application built with Flutter and powered by Supabase.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-181818?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)

## 📱 About

Apollo is a comprehensive messaging application developed as a collaborative university project. This cross-platform app provides seamless communication across all major platforms, built with Flutter's capabilities to offer a native experience on Android, iOS, Web, Windows, Linux, and macOS.

> **Academic Project**: This application was developed as part of a 6th semester Flutter course, showcasing modern mobile development practices and real-time communication features.

## 🎯 Project Milestones

### Phase 1: Foundation ✅
- [x] Project setup and Flutter environment
- [x] Supabase backend configuration
- [x] Basic authentication system
- [x] Initial UI/UX design

### Phase 2: Core Features 🚧
- [x] Private messaging functionality
- [x] Real-time message delivery
- [x] User profile management
- [x] Group chat implementation
- [x] File sharing capabilities

### Phase 3: Advanced Features 🔄
- [x] Voice message recording/playback
- [x] Push notifications
- [x] Online status tracking
- [x] Message editing and replies

### Phase 4: Polish & Testing ⏳
- [x] Cross-platform optimization
- [x] UI/UX refinements
- [x] Comprehensive testing
- [x] Performance optimization
- [x] Final documentation

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
   - Share Supabase credentials with your development partner
   - Update the Supabase credentials in `lib/main.dart`:
     ```dart
     const supabaseUrl = 'YOUR_SUPABASE_URL';
     const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
     ```
   
   > **Important**: Keep your Supabase credentials secure and only share them through secure channels with your teammate.

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
- `blocked_users` - blocked users and their blockers
- `groups` - Group chat information
- `group_members` - group membership 

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

### Collaborative Workflow

#### Branch Strategy
- `main` - Production-ready code
- `dev` - Development integration branch
- `feature/[developer-name]-[feature]` - Individual feature branches

#### Development Process
1. **Daily Coordination**: Regular communication about current work
2. **Feature Assignment**: Clear division of responsibilities
3. **Code Reviews**: Peer review before merging to main
4. **Testing**: Both developers test each other's features
5. **Documentation**: Update docs collaboratively

#### Shared Resources
- **Supabase Database**: Shared backend instance
- **Design Assets**: Collaborative design decisions
- **Persian Documentation**: Available in `documentation_farsi.md`

## 🤝 Contributing

This is currently a private collaborative project. If you're interested in contributing:

1. Contact the development team
2. Fork the repository (if made public)
3. Create a feature branch (`git checkout -b feature/amazing-feature`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Code Style
- Follow Dart/Flutter style guidelines
- Use meaningful variable names
- Add comments for complex logic
- Ensure all tests pass
- Coordinate with team members before major changes

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
- University 6th semester Flutter course for project guidance


<div align="center">
  <strong>Built with ❤️ using Flutter</strong>
</div>