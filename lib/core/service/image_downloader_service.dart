import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageStorageService {
  static final dio = Dio();

  static Future<String?> downloadAndSaveImage(String url, String fileName) async {
    try {
      if (url.isEmpty) return null;

      final directory = await getApplicationDocumentsDirectory();
      final path = p.join(directory.path, 'category_images');

      await Directory(path).create(recursive: true);

      final fileExtension = p.extension(url).split('?').first; // handle query params
      final filePath = p.join(path, '$fileName$fileExtension');
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }

      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.data);
        return filePath;
      }
      return null;
    } catch (e) {
      debugPrint("Error downloading image: $e");
      return null;
    }
  }
}
