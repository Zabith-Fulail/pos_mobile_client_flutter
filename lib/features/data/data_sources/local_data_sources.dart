import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pos_models.dart';

abstract class LocalDataSource {
  Future<String?> getAuthToken();
  Future<void> saveAuthToken(String token);
  Future<void> clearAuthToken();

  Future<String> getBranch();
  Future<void> saveBranch(String branch);

  Future<List<CategoryModel>?> getCategories();
  Future<void> saveCategories(List<CategoryModel> categories);

  Future<List<ProductModel>?> getProducts();
  Future<void> saveProducts(List<ProductModel> products);

  Future<List<String>> getVideoPaths();
  Future<void> saveVideoPaths(List<String> paths);

  Future<List<String>> getImagePaths();
  Future<void> saveImagePaths(List<String> paths);

  Future<Map<String, String>?> getRememberedCredentials();
  Future<void> saveRememberedCredentials(String email, String password);
  Future<void> clearRememberedCredentials();
}

class LocalDataSourceImpl implements LocalDataSource {
  final SharedPreferences prefs;
  LocalDataSourceImpl(this.prefs);

  static const _kAuthToken = 'auth_token';
  static const _kBranch = 'pref_01';
  static const _kCategories = 'local_categories';
  static const _kProducts = 'local_products';
  static const _kVideos = 'carousel_video_paths';
  static const _kImages = 'carousel_image_paths';
  static const _kRemember = 'remember_me';
  static const _kEmail = 'remembered_email';
  static const _kPass = 'remembered_pass';

  @override
  Future<String?> getAuthToken() async => prefs.getString(_kAuthToken);

  @override
  Future<void> saveAuthToken(String token) async =>
      prefs.setString(_kAuthToken, token);

  @override
  Future<void> clearAuthToken() async => prefs.remove(_kAuthToken);

  @override
  Future<String> getBranch() async => prefs.getString(_kBranch) ?? '';

  @override
  Future<void> saveBranch(String branch) async =>
      prefs.setString(_kBranch, branch);

  @override
  Future<List<CategoryModel>?> getCategories() async {
    final raw = prefs.getString(_kCategories);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .map((e) => CategoryModel.fromJson(e))
        .toList();
  }

  @override
  Future<void> saveCategories(List<CategoryModel> categories) async =>
      prefs.setString(_kCategories, jsonEncode(categories.map((c) => c.toJson()).toList()));

  @override
  Future<List<ProductModel>?> getProducts() async {
    final raw = prefs.getString(_kProducts);
    if (raw == null) return null;
    return (jsonDecode(raw) as List).map((e) => ProductModel.fromJson(e)).toList();
  }

  @override
  Future<void> saveProducts(List<ProductModel> products) async =>
      prefs.setString(_kProducts, jsonEncode(products.map((p) => p.toJson()).toList()));

  @override
  Future<List<String>> getVideoPaths() async => prefs.getStringList(_kVideos) ?? [];

  @override
  Future<void> saveVideoPaths(List<String> paths) async =>
      prefs.setStringList(_kVideos, paths);

  @override
  Future<List<String>> getImagePaths() async => prefs.getStringList(_kImages) ?? [];

  @override
  Future<void> saveImagePaths(List<String> paths) async =>
      prefs.setStringList(_kImages, paths);

  @override
  Future<Map<String, String>?> getRememberedCredentials() async {
    if (!(prefs.getBool(_kRemember) ?? false)) return null;
    return {
      'email': prefs.getString(_kEmail) ?? '',
      'password': prefs.getString(_kPass) ?? '',
    };
  }

  @override
  Future<void> saveRememberedCredentials(String email, String password) async {
    await prefs.setBool(_kRemember, true);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kPass, password);
  }

  @override
  Future<void> clearRememberedCredentials() async {
    await prefs.remove(_kRemember);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPass);
  }
}