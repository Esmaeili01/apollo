import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineStatusManager with WidgetsBindingObserver {
  static final OnlineStatusManager _instance = OnlineStatusManager._internal();
  factory OnlineStatusManager() => _instance;
  OnlineStatusManager._internal();

  Timer? _heartbeat;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(); // initial call
    _startHeartbeat();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
  }

  Future<void> _setOnline() async {
    await Future.delayed(Duration(milliseconds: 500));
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('profiles')
        .update({
          'is_online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) => _setOnline());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline();
    }
  }
}
