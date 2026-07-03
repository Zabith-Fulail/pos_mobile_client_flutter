// lib/core/service/global_image_settings.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that holds the global "show local images" toggle.
/// Persisted via SharedPreferences so it survives restarts.
class GlobalImageSettings extends ChangeNotifier {
  static final GlobalImageSettings _instance = GlobalImageSettings._();
  factory GlobalImageSettings() => _instance;
  GlobalImageSettings._();

  static const _key = 'global_show_local_images';

  bool _showLocalImages = true;

  bool get showLocalImages => _showLocalImages;

  /// Call once at app start (e.g. in main.dart or your DI setup).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _showLocalImages = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> setShowLocalImages(bool value) async {
    _showLocalImages = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}