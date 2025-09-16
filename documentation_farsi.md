# مستندات کامل اپلیکیشن Apollo Flutter
## صفحات احراز هویت و خانه

این مستند شامل توضیح کامل کدهای صفحات ورود، ثبت‌نام و خانه اپلیکیشن Apollo است.

---

## فایل lib/pages/login.dart - صفحه ورود

### معرفی کلی
صفحه ورود (LoginPage) یک StatefulWidget است که امکان ورود کاربران با ایمیل و رمز عبور را فراهم می‌کند.

### واردات (Imports)

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\login.dart start=1
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:another_flushbar/flushbar.dart';
import 'signup.dart';
import '../utils/online_status_manager.dart';
```

**توضیح واردات:**
- `flutter/material.dart`: برای استفاده از Material Design widgets
- `supabase_flutter/supabase_flutter.dart`: برای احراز هویت و اتصال به پایگاه داده
- `another_flushbar/flushbar.dart`: برای نمایش پیام‌های خطا
- `signup.dart`: برای انتقال به صفحه ثبت‌نام
- `online_status_manager.dart`: برای مدیریت وضعیت آنلاین کاربر

### تعریف کلاس و متغیرها

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\login.dart start=14
class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
```

**توضیح متغیرها:**
- `emailController`: کنترل کننده فیلد ایمیل
- `passwordController`: کنترل کننده فیلد رمز عبور
- `_formKey`: کلید منحصر به فرد برای فرم
- `isLoading`: وضعیت بارگذاری

### متد انتقال به صفحه ثبت‌نام با انیمیشن

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\login.dart start=21
void _goToSignup() {
  Navigator.of(
    context,
  ).push(_createSlideRoute(const SignupPage(), AxisDirection.left));
}

Route _createSlideRoute(Widget page, AxisDirection direction) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const beginOffset = Offset(1.0, 0.0); // Slide from right
      const endOffset = Offset.zero;
      final tween = Tween(
        begin: beginOffset,
        end: endOffset,
      ).chain(CurveTween(curve: Curves.ease));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
```

**توضیح:**
این متد انیمیشن لغزش از سمت راست برای انتقال به صفحه ثبت‌نام ایجاد می‌کند.

### متد ورود کاربر

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\login.dart start=42
Future<void> _signIn() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() {
    isLoading = true;
  });
  final email = emailController.text.trim();
  final password = passwordController.text;
  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user != null) {
      if (!mounted) return;
      OnlineStatusManager().start(); 
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showError('Login failed. Please try again.');
    }
  } on AuthException catch (e) {
    _showError(e.message);
  } catch (e) {
    _showError('Unexpected error: $e');
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}
```

**توضیح مراحل ورود:**
1. اعتبارسنجی فرم
2. فعال کردن وضعیت بارگذاری
3. دریافت اطلاعات ایمیل و رمز عبور
4. تلاش برای ورود با Supabase
5. شروع مدیریت وضعیت آنلاین
6. انتقال به صفحه اصلی

### متد نمایش خطا

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\login.dart start=71
void _showError(String message) {
  Flushbar(
    message: message,
    duration: const Duration(seconds: 3),
    backgroundColor: Colors.red.shade600,
    margin: const EdgeInsets.all(16),
    borderRadius: BorderRadius.circular(12),
    icon: const Icon(Icons.error_outline, color: Colors.white),
    flushbarPosition: FlushbarPosition.TOP,
    animationDuration: const Duration(milliseconds: 500),
  ).show(context);
}
```

**ویژگی‌های Flushbar:**
- نمایش در بالای صفحه
- رنگ قرمز برای خطا
- نمایش به مدت 3 ثانیه
- انیمیشن نرم

### طراحی رابط کاربری (UI)

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\login.dart start=86
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
```

**ویژگی‌های طراحی:**
- گرادیان زیبا با رنگ‌های بنفش و آبی
- کارت مرکزی با لبه‌های گرد
- فیلدهای ورودی با پیش‌نمادهای مناسب
- دکمه ورود با گرادیان

---

## فایل lib/pages/signup.dart - صفحه ثبت‌نام

### معرفی کلی
صفحه ثبت‌نام شامل فیلدهای نام، ایمیل، رمز عبور و تایید رمز عبور است.

### متغیرهای کنترل

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\signup.dart start=13
final TextEditingController nameController = TextEditingController();
final TextEditingController emailController = TextEditingController();
final TextEditingController passwordController = TextEditingController();
final TextEditingController confirmPasswordController = TextEditingController();
```

### اعتبارسنجی رمز عبور

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\signup.dart start=22
bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(passwordController.text);
bool get _hasDigit => RegExp(r'\\d').hasMatch(passwordController.text);
bool get _minLength => passwordController.text.length >= 6;
bool get _passwordsMatch =>
    passwordController.text == confirmPasswordController.text &&
    passwordController.text.isNotEmpty;
```

**شرایط اعتبارسنجی:**
- داشتن حداقل یک حرف
- داشتن حداقل یک عدد
- حداقل 6 کاراکتر
- تطابق رمز عبور و تایید آن

### متد ثبت‌نام

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\signup.dart start=54
Future<void> _signUp() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() {
    isLoading = true;
  });
  final email = emailController.text.trim();
  final password = passwordController.text;
  final name = nameController.text.trim();
  try {
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user != null) {
      // Insert profile info (name) into 'profiles' table
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'name': name,
      });
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/profile-completion');
    }
  } catch (e) {
    _showError('Failed to create account');
  }
}
```

**مراحل ثبت‌نام:**
1. ایجاد حساب کاربری در Supabase
2. ذخیره اطلاعات پروفایل در جدول profiles
3. انتقال به صفحه تکمیل پروفایل

### چک‌لیست اعتبارسنجی

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\signup.dart start=370
Widget _buildChecklistItem(String text, bool isChecked) {
  return Row(
    children: [
      Icon(
        isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isChecked ? Colors.green : Colors.grey,
        size: 20,
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          color: isChecked ? Colors.green : Colors.grey,
          fontSize: 14,
        ),
      ),
    ],
  );
}
```

این widget نمایش بصری شرایط اعتبارسنجی رمز عبور را فراهم می‌کند.

---

## فایل lib/pages/home.dart - صفحه اصلی

### معرفی کلی
صفحه اصلی مرکز کنترل اپلیکیشن است که شامل لیست چت‌های خصوصی و گروه‌ها می‌باشد.

### متغیرهای state

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\home.dart start=17
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isDialOpen = false;
  bool _isMenuOpen = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _chatOffset;
  late Animation<Offset> _groupOffset;
  late AnimationController _menuController;

  int _selectedChatTab = 0; // 0: PV, 1: Group

  List<Map<String, dynamic>> _privateChats = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loadingChats = false;
  bool _loadingGroups = false;
  Map<String, dynamic>? _userProfile;
  
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _groupMessagesChannel;
```

### راه‌اندازی اولیه

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\home.dart start=40
@override
void initState() {
  super.initState();
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  
  _fetchPrivateChats();
  _fetchGroups();
  _fetchUserProfile();
  _setupRealtimeSubscriptions();
}
```

### تنظیم Realtime Subscriptions

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\home.dart start=101
void _setupRealtimeSubscriptions() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  // Subscribe to private messages
  _messagesChannel = Supabase.instance.client
      .channel('home-messages')
      .on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
        ),
        (payload, [ref]) {
          try {
            final newMessage = payload['new'] as Map<String, dynamic>;
            
            if (newMessage['group_id'] == null) {
              if (newMessage['sender_id'] == user.id || 
                  newMessage['receiver_id'] == user.id) {
                _handleNewPrivateMessage(newMessage);
              }
            }
          } catch (e) {
            print('Error processing message in home page: $e');
          }
        },
      );
  
  _messagesChannel?.subscribe();
}
```

**ویژگی‌های Realtime:**
- گوش دادن به پیام‌های جدید
- به‌روزرسانی فوری لیست چت‌ها
- مدیریت پیام‌های خوانده نشده

### دریافت چت‌های خصوصی

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\home.dart start=307
Future<void> _fetchPrivateChats() async {
  setState(() => _loadingChats = true);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  
  final res = await Supabase.instance.client
      .from('messages')
      .select(
        'id, sender_id, receiver_id, content, created_at, is_seen, sender:sender_id (id, name, avatar_url), receiver:receiver_id (id, name, avatar_url)',
      )
      .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
      .is_('group_id', null)
      .order('created_at', ascending: false);
      
  // Group by contact and count unread messages
  final Map<String, Map<String, dynamic>> chatMap = {};
  final Map<String, int> unreadCounts = {};
  
  for (final msg in res) {
    final isSender = msg['sender_id'] == user.id;
    final contact = isSender ? msg['receiver'] : msg['sender'];
    if (contact == null || contact['id'] == null) continue;
    final contactId = contact['id'];
    
    // Count unread messages
    if (!isSender && !(msg['is_seen'] ?? false)) {
      unreadCounts[contactId] = (unreadCounts[contactId] ?? 0) + 1;
    }
    
    if (!chatMap.containsKey(contactId)) {
      chatMap[contactId] = {
        'contact': contact,
        'lastMessage': msg['content'],
        'lastMessageTime': msg['created_at'],
        'isSeen': msg['is_seen'],
        'isCurrentUserSender': isSender,
        'unreadCount': unreadCounts[contactId] ?? 0,
      };
    }
  }
}
```

### طراحی رابط کاربری اصلی

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\home.dart start=548
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Apollo', style: TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    ),
```

### تب‌های چت (PV و Groups)

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\home.dart start=1319
class _ChatTabs extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5BFF), Color(0xFF46C2CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatTab(
            label: 'PV',
            selected: selected == 0,
            onTap: () => onSelect(0),
          ),
          const SizedBox(width: 8),
          _ChatTab(
            label: 'Groups',
            selected: selected == 1,
            onTap: () => onSelect(1),
          ),
        ],
      ),
    );
  }
}
```

### Floating Action Button با انیمیشن

```dart path=F:\PROJECTS\newapollo\apollo\lib\pages\home.dart start=1048
floatingActionButton: Padding(
  padding: const EdgeInsets.only(bottom: 16, right: 16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (_isDialOpen) ...[
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _groupOffset,
            child: FloatingActionButton(
              heroTag: 'group',
              mini: true,
              onPressed: _onNewGroup,
              child: const Icon(Icons.group_add, color: Colors.white),
              tooltip: 'New Group',
            ),
          ),
        ),
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _chatOffset,
            child: FloatingActionButton(
              heroTag: 'chat',
              mini: true,
              onPressed: _onNewChat,
              child: const Icon(Icons.chat, color: Colors.white),
              tooltip: 'New Chat',
            ),
          ),
        ),
      ],
      FloatingActionButton(
        onPressed: _isDialOpen ? _closeDial : _toggleDial,
        child: AnimatedRotation(
          turns: _isDialOpen ? 0.125 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _isDialOpen ? Icons.close : Icons.add,
            color: Colors.white,
          ),
        ),
      ),
    ],
  ),
),
```

---

