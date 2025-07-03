// *************** THIS FILE IS NOT NEEDED WHEN USING CRON 
// ****************CRON IS RUNNING EVERY 20-30 SECONDS AND CHANGE THE IS_ONLINE IF TABLE PROFILE [S]




// import 'package:flutter/widgets.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class OnlineStatusManager with WidgetsBindingObserver {
//   static final OnlineStatusManager _instance = OnlineStatusManager._internal();
//   factory OnlineStatusManager() => _instance;
//   OnlineStatusManager._internal();

//   void start() {
//     WidgetsBinding.instance.addObserver(this);
//     _setOnline();
//   }

//   void stop() {
//     WidgetsBinding.instance.removeObserver(this);
//     _setOffline();
//   }

//   // Future<void> _setOnline() async {
//   //   final user = Supabase.instance.client.auth.currentUser;
//   //   if (user == null) return;
//   //   await Supabase.instance.client
//   //       .from('profiles')
//   //       .update({'is_online': true})
//   //       .eq('id', user.id);
//   // }

//   // Future<void> _setOffline() async {
//   //   final user = Supabase.instance.client.auth.currentUser;
//   //   if (user == null) return;
//   //   await Supabase.instance.client
//   //       .from('profiles')
//   //       .update({
//   //         'is_online': false,
//   //         'last_seen': DateTime.now().toUtc().toIso8601String(),
//   //       })
//   //       .eq('id', user.id);
//   // }

// //   @override
// //   void didChangeAppLifecycleState(AppLifecycleState state) {
// //     if (state == AppLifecycleState.resumed) {
// //       _setOnline();
// //     } else if (state == AppLifecycleState.paused ||
// //         state == AppLifecycleState.inactive ||
// //         state == AppLifecycleState.detached) {
// //       _setOffline();
// //     }
// //   }
// }