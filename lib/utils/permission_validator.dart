import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    if (androidInfo.version.sdkInt >= 33) {
      // Android 13+
      final images = await Permission.photos.request();
      final videos = await Permission.videos.request();
      return images.isGranted && videos.isGranted;
    } else {
      // Android 12 and below
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
  }
  return true;
}
