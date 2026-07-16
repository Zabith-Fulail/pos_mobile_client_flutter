import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/data/data_sources/local_data_sources.dart';
import '../../features/data/data_sources/remote_data_sources.dart';
import '../../features/data/repositories/repository_impl.dart';
import '../../features/domain/repositories/repository.dart';
import '../../features/domain/use_cases/categories_use_case.dart';
import '../../features/domain/use_cases/extract_order_from_speech_use_case.dart';
import '../../features/domain/use_cases/get_running_orders_use_case.dart';
import '../../features/domain/use_cases/login_use_case.dart';
import '../../features/domain/use_cases/logout_use_case.dart';
import '../../features/domain/use_cases/main_screen_data_use_case.dart';
import '../../features/domain/use_cases/print_running_order_use_case.dart';
import '../../features/domain/use_cases/submit_kot_use_case.dart';
import '../../features/presentation/cubit/login/login_cubit.dart';
import '../../features/presentation/cubit/logout/logout_cubit.dart';
import '../../features/presentation/cubit/manage_categories/manage_categories_cubit.dart';
import '../../features/presentation/cubit/manage_products/manage_products_cubit.dart';
import '../../features/presentation/cubit/order_entry/order_entry_cubit.dart';
import '../../features/presentation/cubit/running_orders/running_orders_cubit.dart';
import '../network/api_helper.dart';
import '../network/network_info.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(
      accessibility:
          KeychainAccessibility.first_unlock, // Ensures data is accessible
    ),
  );
  sl.registerLazySingleton<ApiHelper>(() => ApiHelper(dio: sl()));
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => secureStorage);
  // sl.registerLazySingleton<AIOrderExtractionService>(
  //       () => AIOrderExtractionService(),
  // );

  /// Dio client
  sl.registerLazySingleton<Dio>(() => Dio());

  /// Data sources
  sl.registerLazySingleton<LocalDataSource>(
        () => LocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<RemoteDataSource>(
    () => RemoteDataSourceImpl(apiHelper: sl()),
  );

  /// Repository
  sl.registerLazySingleton<Repository>(
    () => RepositoryImpl(
      // localDataSource: sl(),
      networkInfo: sl(),
      remoteDataSource: sl(),
    ),
  );

  /// Cubit

  sl.registerFactory<LoginCubit>(
    () => LoginCubit(
      loginUseCase: sl(),
      localDataSource: sl()
    ),
  );
  sl.registerFactory<OrderEntryCubit>(
    () => OrderEntryCubit(
      repository: sl(),
      localDataSource: sl(),
      mainScreenDataUseCase: sl(),
      submitKitchenOrderUseCase: sl(),
      categoriesUseCase: sl(),
      extractOrderFromSpeechUseCase: sl()
      // aiService: sl<AIOrderExtractionService>()
    ),
  );

  sl.registerFactory(
    () => RunningOrdersCubit(
      getRunningOrdersUseCase: sl(),
      printRunningOrderUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => CategoriesCubit(
     categoriesUseCase: sl()
    ),
  );
  sl.registerFactory(() => LogoutCubit(logoutUseCase: sl()));
  sl.registerFactory(() => ProductsCubit(repository: sl()));
  /// Use cases
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => MainScreenDataUseCase(sl()));
  sl.registerLazySingleton(() => GetRunningOrdersUseCase(sl()));
  sl.registerLazySingleton(() => PrintRunningOrderUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => SubmitKitchenOrderUseCase(sl()));
  sl.registerLazySingleton(() => CategoriesUseCase(sl()));
  sl.registerLazySingleton(() => ExtractOrderFromSpeechUseCase(sl()));
}
