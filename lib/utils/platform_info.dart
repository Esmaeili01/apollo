import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformInfo {
  static String getPlatformName() {
    if (kIsWeb) {
      return 'Web';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isLinux) {
      return 'Linux';
    } else {
      return 'Unknown';
    }
  }

  static String getOSVersion() {
    if (kIsWeb) {
      return 'Web Browser';
    } else {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    }
  }

  static bool get isMobile {
    return Platform.isAndroid || Platform.isIOS;
  }

  static bool get isDesktop {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool get isWeb {
    return kIsWeb;
  }

  static String getDetailedInfo() {
    if (kIsWeb) {
      return 'Web Browser';
    } else {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    }
  }
}
