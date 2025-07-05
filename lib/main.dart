import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html;
import 'utils/online_status_manager.dart';
import 'pages/splash.dart';
import 'pages/login.dart';
import 'pages/signup.dart';
import 'pages/home.dart';
import 'pages/profile_completion.dart';

const supabaseUrl = 'https://ntlftadhcescxldsaytg.supabase.co';
const supabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50bGZ0YWRoY2VzY3hsZHNheXRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkzMjQzMDMsImV4cCI6MjA2NDkwMDMwM30.ILmzaa8bUBx3IK1UkKh2Fd8x4wOjusxVvX2xVMIm6s8";

String? currentOpenChatContactId; // Track the currently open chat globally
RealtimeChannel? _globalMessagesSub;

void subscribeToAllMessages(String userId) {
  _globalMessagesSub = Supabase.instance.client
      .channel('all-messages-$userId')
      .on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: 'INSERT', schema: 'public', table: 'messages'),
        (payload, [ref]) async {
          final newMessage = payload['new'] as Map<String, dynamic>;
          final isMine = newMessage['sender_id'] == userId;
          final isForMe = newMessage['receiver_id'] == userId;
          final contactId = isMine
              ? newMessage['receiver_id']
              : newMessage['sender_id'];
          // Only notify if not in the chat with this contact
          if (isForMe && currentOpenChatContactId != contactId) {
            // Fetch notification setting for this contact
            final res = await Supabase.instance.client
                .from('contacts')
                .select('notifications_enabled')
                .eq('user_id', userId)
                .eq('contact_id', contactId)
                .maybeSingle();
            final notificationsEnabled = res?['notifications_enabled'] ?? true;
            if (notificationsEnabled &&
                html.document.visibilityState != 'visible') {
              if (html.Notification.permission != 'granted') {
                await html.Notification.requestPermission();
              }
              if (html.Notification.permission == 'granted') {
                html.Notification(
                  'New message',
                  body: newMessage['content'] ?? 'Media message',
                  // Optionally fetch sender's avatar for icon
                );
              }
            }
          }
        },
      );
  _globalMessagesSub?.subscribe();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  OnlineStatusManager().start();  
  runApp(MyApp());
}


class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateLastSeen(); // Update on app start
    // Subscribe to global notifications if logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      subscribeToAllMessages(user.id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateLastSeen(); // Update when app comes to foreground
    }
  }

  Future<void> _updateLastSeen() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('profiles')
        .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
        .eq('id', user.id);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
        '/profile-completion': (context) => const ProfileCompletionPage(),
      },
    );
  }
}
