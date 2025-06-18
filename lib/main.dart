import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/online_status_manager.dart';
import 'pages/splash.dart';
import 'pages/login.dart';
import 'pages/signup.dart';
import 'pages/home.dart';
import 'pages/profile_completion.dart';

const supabaseUrl = 'https://ntlftadhcescxldsaytg.supabase.co';
const supabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50bGZ0YWRoY2VzY3hsZHNheXRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkzMjQzMDMsImV4cCI6MjA2NDkwMDMwM30.ILmzaa8bUBx3IK1UkKh2Fd8x4wOjusxVvX2xVMIm6s8";
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
        .update({'last_seen': DateTime.now().toIso8601String()})
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
