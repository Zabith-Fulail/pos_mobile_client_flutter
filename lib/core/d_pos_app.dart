import 'package:d_pos/core/service/dependency_injection.dart';
import 'package:d_pos/core/service/theme_data.dart';
import 'package:d_pos/features/presentation/cubit/login/login_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../features/presentation/cubit/order_entry/order_entry_cubit.dart';
import '../utils/app_constants.dart';
import '../utils/navigation_routes.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LoginCubit>(create: (_) => sl<LoginCubit>()),
        BlocProvider<OrderEntryCubit>(create: (_) => sl<OrderEntryCubit>()),
      ],
      child: ScreenUtilInit(
        builder: (_, state) {
          return MaterialApp(
            theme: posTheme,
            navigatorKey: Routes.navigatorKey,
            title: AppConstants.appName,
            initialRoute: initialRoute,
            onGenerateRoute: Routes.generateRoute,
          );
        },
      ),
    );
  }
}
