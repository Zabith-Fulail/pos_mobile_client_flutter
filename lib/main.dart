import 'package:d_pos/utils/app_constants.dart';
import 'package:d_pos/utils/navigation_routes.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/d_pos_app.dart';
import 'core/service/dependency_injection.dart';
import 'core/service/global_image_settings.dart';
import 'features/data/data_sources/local_data_sources.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initDependencies();
  await GlobalImageSettings().load();
  final prefs = await SharedPreferences.getInstance();
  final String? savedToken = prefs.getString('auth_token');
  final bool hasToken = savedToken != null && savedToken.isNotEmpty;

  if (hasToken) {
    AppConstants.accessToken = savedToken;
  }

  String startRoute;

  if (AppConstants.useMockData) {
    AppConstants.accessToken = 'mock-token';
    AppConstants.userId = 1;
    startRoute = Routes.kMainPosScreen;
  } else {
    final localDataSource = sl<LocalDataSource>();
    final savedToken = await localDataSource.getAuthToken();
    final hasToken = savedToken != null && savedToken.isNotEmpty;
    if (hasToken) AppConstants.accessToken = savedToken;
    startRoute = hasToken ? Routes.kMainPosScreen : Routes.kLoginScreen;
  }

  runApp(MyApp(initialRoute: startRoute));
}