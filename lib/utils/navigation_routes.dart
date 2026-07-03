import 'package:d_pos/features/presentation/views/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/service/dependency_injection.dart';
import '../features/presentation/cubit/order_entry/order_entry_cubit.dart';
import '../features/presentation/views/login/login_view.dart';
import '../features/presentation/views/main_dashboard/main_pos_screen.dart';

class Routes {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const String kSplashView = 'kSplashView';
  static const String kLoginScreen = 'kLoginScreen';
  static const String kMainPosScreen = 'kMainPosScreen';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case kSplashView:
        return _slideTransition(const SplashView(), kSplashView);
      case kLoginScreen:
        return _slideTransition(LoginScreen(), kLoginScreen);
      case kMainPosScreen:
        return _slideTransition(
          BlocProvider(
            create: (context) => sl<OrderEntryCubit>()..loadInitialData(),
            child: const MainPosScreen(),
          ),
          kMainPosScreen,
        );

      default:
        return _slideTransition(
          Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          'undefined',
        );
    }
  }

  static Route _slideTransition(Widget page, String name) {
    return PageRouteBuilder(
      settings: RouteSettings(name: name),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0); // slide from right
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);

        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}
