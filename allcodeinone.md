import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';

import '../../error/exceptions.dart';
import '../../features/data/models/response/error_response_model.dart';
import '../../features/presentation/widget/app_dialog.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_enum.dart';
import '../../utils/navigation_routes.dart';

class ApiHelper {
final Dio dio;

ApiHelper({required this.dio}) {
dio.options
..baseUrl = "https://sample.com/api/"
..connectTimeout = const Duration(seconds: AppConstants.connectionTimeout)
..receiveTimeout = const Duration(seconds: AppConstants.connectionTimeout)
..headers = {"Content-Type": "application/json", "Accept": "*/*"};
dio.interceptors.addAll([
InterceptorsWrapper(
onRequest: (options, handler) async {
final token = AppConstants.accessToken;
if (token != null && token.isNotEmpty) {
options.headers["Authorization"] = "Bearer $token";
}
if (options.data != null) {
log("Request Body: ${_prettyJson(options.data)}");
}
return handler.next(options);
},
onResponse: (response, handler) {
log("Response Body: ${_prettyJson(response.data)}");
return handler.next(response);
},
onError: (DioException e, handler) async {
final response = e.response;
final requestOptions = e.requestOptions;

          if (response?.statusCode == 401) {
            final serverErrorCode = response?.data['statusCode'];

            if (serverErrorCode == "010") {
              log("Invalid Token (010) detected. Logging out...");

              AppConstants.accessToken = null;

              final context = Routes.navigatorKey.currentContext;

              if (context != null) {
                Future.delayed(Duration.zero, () {
                  showAppDialog(
                    message:
                        "Your session is invalid or has expired. Please login again.",
                    title: "Session Expired",
                    context: context,
                    type: AppDialogType.error,
                    onConfirmPressed: () {
                      Navigator.of(context).pop();

                      ///todo : uncomment this
                      // Navigate to Login and remove all back stack
                      // Routes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                      //   Routes.kMobileNumberView,
                      //       (route) => false,
                      // );
                    },
                    confirmButtonText: "ok",
                  );
                });
              }
              return handler.reject(e);
            }

            if (serverErrorCode == "011") {
              if (!_isRefreshing) {
                _isRefreshing = true;
                final newToken = await _refreshToken();
                _isRefreshing = false;

                if (newToken != null) {
                  for (final retry in _retryQueue) {
                    await retry(newToken);
                  }
                  _retryQueue.clear();

                  final opts = requestOptions.copyWith(
                    headers: {
                      ...requestOptions.headers,
                      "Authorization": "Bearer $newToken",
                    },
                  );
                  final response = await dio.fetch(opts);
                  return handler.resolve(response);
                } else {
                  AppConstants.accessToken = null;
                  final context = Routes.navigatorKey.currentContext;

                  if (context != null) {
                    Future.delayed(Duration.zero, () {
                      showAppDialog(
                        message:
                            "Your session is invalid or has expired. Please login again.",
                        title: "Session Expired",
                        context: context,
                        type: AppDialogType.error,
                        onConfirmPressed: () {
                          Navigator.of(context).pop();

                          ///todo : uncomment this
                          // Navigate to Login and remove all back stack
                          // Routes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                          //   Routes.kMobileNumberView,
                          //       (route) => false,
                          // );
                        },
                        // cancelButtonText: "Cancel",
                        confirmButtonText: "ok",
                      );
                    });
                  }
                  return handler.reject(e);
                }
              } else {
                _retryQueue.add((String token) async {
                  final opts = requestOptions.copyWith(
                    headers: {
                      ...requestOptions.headers,
                      "Authorization": "Bearer $token",
                    },
                  );
                  final response = await dio.fetch(opts);
                  handler.resolve(response);
                });
                return;
              }
            }
          }
          return handler.next(e);
        },
      ),
      LogInterceptor(requestBody: false, responseBody: false),
    ]);
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
}

bool _isRefreshing = false;
final List<Future<void> Function(String)> _retryQueue = [];

Future<String?> _refreshToken() async {
try {
final refreshToken = AppConstants.accessToken;
if (refreshToken == null) return null;

      final response = await dio.post(
        "mobile/auth/refresh-token",
        data: {"refreshToken": refreshToken},
        options: Options(headers: {"Authorization": null}),
      );

      if (response.statusCode == 200 && response.data['statusCode'] == "000") {
        final responseData = response.data['data'];

        final newAccessToken = responseData['token'];

        final newRefreshToken = responseData['refreshToken'];

        if (newAccessToken != null) {
          AppConstants.accessToken = newAccessToken;
          // await source.saveAccessToken(newAccessToken);
          // source.setAccessToken(newAccessToken);

          if (newRefreshToken != null) {
            AppConstants.refreshToken = newAccessToken;
            // await source.setRefreshToken(newRefreshToken);
          }

          return newAccessToken;
        }
      }

      return null;
    } catch (e) {
      log("Token Refresh Failed: $e");
      return null;
    }
}

String _prettyJson(dynamic data) {
try {
return jsonEncode(data);
} catch (e) {
return data.toString();
}
}

Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
try {
final response = await dio.get(path, queryParameters: queryParams);
return response.data;
} on DioException catch (e) {
if (e.response?.statusCode == 400 ||
e.response?.statusCode == 401 ||
e.response?.statusCode == 404) {
log("DioException ${e.response?.data}");
throw ServerException(ErrorResponseModel.fromJson(e.response?.data));
}
log("DioException ${e.message}");
throw ServerException(ErrorResponseModel(errorDescription: e.message));
}
}

Future<dynamic> post(String path, {dynamic data}) async {
try {
final response = await dio.post(path, data: data);
return response.data;
} on DioException catch (e) {
if (e.response?.statusCode == 400 ||
e.response?.statusCode == 401 ||
e.response?.statusCode == 500) {
log("DioException ${e.response?.data}");
throw ServerException(ErrorResponseModel.fromJson(e.response?.data));
}
log("DioException ${e.message}");
throw ServerException(ErrorResponseModel(errorDescription: e.message));
}
}

Future<dynamic> put(String path, {dynamic data}) async {
try {
final response = await dio.put(path, data: data);
return response.data;
} on DioException catch (e) {
if (e.response?.statusCode == 400 ||
e.response?.statusCode == 401 ||
e.response?.statusCode == 500) {
log("DioException ${e.response?.data}");
throw ServerException(ErrorResponseModel.fromJson(e.response?.data));
}
log("DioException ${e.message}");
throw ServerException(ErrorResponseModel(errorDescription: e.message));
}
}

Future<Response> delete(String path, {dynamic data}) async {
return await dio.delete(path, data: data);
}
}
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo {
Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
final Connectivity connectionChecker;

const NetworkInfoImpl(this.connectionChecker);

@override
Future<bool> get isConnected async {
var connectivityResult = await connectionChecker.checkConnectivity();
if (connectivityResult.contains(ConnectivityResult.mobile)) {
return true;
} else if (connectivityResult.contains(ConnectivityResult.wifi)) {
return true;
} else if (connectivityResult.contains(ConnectivityResult.none)) {
return false;
} else {
return false;
}
}
}
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
}
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
}import 'dart:io';
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
import 'package:flutter/material.dart';

final ThemeData posTheme = ThemeData(
useMaterial3: true,
brightness: Brightness.light,
primaryColor: const Color(0xFF76D61D),
scaffoldBackgroundColor: const Color(0xFFF4F5F7),
splashColor: const Color(0xFF76D61D).withValues(alpha: 0.1),
colorScheme: const ColorScheme.light(
primary: Color(0xFF76D61D),
onPrimary: Colors.white,
secondary: Color(0xFF2D3436),
error: Color(0xFFE53935),
surface: Colors.white,
onSurface: Color(0xFF2D3436),
),

inputDecorationTheme: InputDecorationTheme(
filled: true,
fillColor: Colors.white,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: BorderSide.none,
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: const BorderSide(color: Color(0xFF76D61D), width: 2),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
),

elevatedButtonTheme: ElevatedButtonThemeData(
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF76D61D),
foregroundColor: Colors.white,
elevation: 0,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
padding: const EdgeInsets.symmetric(vertical: 16),
),
),

textTheme: const TextTheme(
headlineMedium: TextStyle(
fontWeight: FontWeight.w800,
color: Color(0xFF2D3436),
fontSize: 24,
),
bodyLarge: TextStyle(
fontWeight: FontWeight.w600,
color: Color(0xFF2D3436),
fontSize: 16,
),
bodyMedium: TextStyle(color: Colors.grey, fontSize: 14),
titleLarge: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 18,
color: Color(0xFF2D3436),
),
),
);
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
import 'failures.dart';

class ErrorMessages {
///error_title
static const String title = "Error";

///error_messages
static const String errorSomethingWentWrong = "Something went wrong!";
static const String errorAppVerificationFailed = "App verification failed!";
static const String errorMessage1 = "Entered Passwords are not match";
static const String errorMessage2 =
"Invalid details. Please enter correct username and password";
static const String errorMessage3 = "Please Enter PIN";
static const String errorMessageAlreadyExistingNIC = "NIC already exits";
static const String fileIsTooLarge =
"The file you are trying to upload is too large.";
static const String methodNotAllowed = "405 \n Method Not Allowed.";
static const String errorConnectionTimeout =
"Connection timed out. Please try again.";

///Login View
static const String emptyUsername = "Username cannot be empty";
static const String emptyPassword = "Password cannot be empty";

String? mapFailureToMessage(Failure failure) {
switch (failure.runtimeType) {
case ConnectionFailure:
return 'No internet connection detected.';
case ServerFailure:
return (failure as ServerFailure).errorResponse.errorDescription;
case AuthorizedFailure:
return (failure as AuthorizedFailure).errorResponse.errorDescription;
default:
return 'Unexpected error';
}
}
}
import 'package:dio/dio.dart';

import '../features/data/models/response/error_response_model.dart';

class ServerException implements Exception {
final ErrorResponseModel errorResponseModel;
final DioExceptionType? errorType;

ServerException(this.errorResponseModel, {this.errorType});
}

class CacheException implements Exception {}

class UnAuthorizedException implements Exception {
final ErrorResponseModel errorResponseModel;

UnAuthorizedException(this.errorResponseModel);
}

class DioExceptions implements Exception {
final ErrorResponseModel? errorResponseModel;

DioExceptions({this.errorResponseModel});
}
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../features/data/models/response/error_response_model.dart';

abstract class Failure extends Equatable {
const Failure();

@override
List<Object?> get props => [];
}

class ServerFailure extends Failure {
final ErrorResponseModel errorResponse;
final DioExceptionType? errorType;

const ServerFailure(this.errorResponse, {this.errorType});

@override
List<Object?> get props => [errorResponse, errorType];
}

class CacheFailure extends Failure {
@override
List<Object?> get props => [];
}

class ConnectionFailure extends Failure {
@override
List<Object?> get props => [];
}

class AuthorizedFailure extends Failure {
final ErrorResponseModel errorResponse;

const AuthorizedFailure(this.errorResponse);

@override
List<Object?> get props => [errorResponse];
}
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
}import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';

import '../../../core/network/api_helper.dart';
import '../models/common/base_response.dart';
import '../models/request/place_order_request.dart';
import '../models/response/main_screen_response.dart';
import '../models/response/place_order_response.dart';
import '../models/response/print_response_model.dart';
import '../models/response/running_orders_response_model.dart';


abstract class RemoteDataSource {
Future<LoginResponse> login(LoginRequest loginRequest);

Future<MainScreenResponse> getMainScreenData();

Future<BaseResponse<RunningOrderData>> getRunningOrders(int id);

Future<PrintResponseModel> printRunningOrder(int orderId);

Future<KitchenOrderResponse> submitKitchenOrder(PlaceOrderRequest request);
}

class RemoteDataSourceImpl implements RemoteDataSource {
final ApiHelper apiHelper;

RemoteDataSourceImpl({required this.apiHelper});

@override
Future<LoginResponse> login(LoginRequest loginRequest) async {
try {
final response = await apiHelper.post(
"login",
data: loginRequest.toJson(),
);
return LoginResponse.fromJson(response);
} on Exception {
rethrow;
}
}

@override
Future<MainScreenResponse> getMainScreenData() async {
try {
final response = await apiHelper.get("main-screen-data");
return MainScreenResponse.fromJson(response['data']);
} on Exception {
rethrow;
}
}

@override
Future<BaseResponse<RunningOrderData>> getRunningOrders(int id) async {
try {
final response = await apiHelper.get("running-orders/$id");
return BaseResponse<RunningOrderData>.fromJson(
response,
(data) => RunningOrderData.fromJson(data),
);
} on Exception {
rethrow;
}
}

@override
Future<PrintResponseModel> printRunningOrder(int orderId) async {
try {
final response = await apiHelper.post(
"running-orders/print/$orderId",
data: {},
);
return PrintResponseModel.fromJson(response);
} on Exception {
rethrow;
}
}

@override
Future<KitchenOrderResponse> submitKitchenOrder(PlaceOrderRequest request) async {
try {
final response = await apiHelper.post(
"waiter/kitchen-orders/submit",
data: request.toJson(),
);
return KitchenOrderResponse.fromJson(response);
} on Exception {
rethrow;
}
}
}
// To parse this JSON data, do
//
//     final apiResponse = apiResponseFromJson(jsonString);

import 'dart:convert';

BaseResponse apiResponseFromJson(String str) =>
BaseResponse.fromJson(json.decode(str), (data) => data);

String apiResponseToJson(BaseResponse data) => json.encode(data.toJson());

class BaseResponse<T extends Serializable> {
BaseResponse({
this.message,
this.timestamp,
this.success,
this.data,
});

final bool? success;
final String? message;
final String? timestamp;
T? data;

factory BaseResponse.fromJson(
Map<String, dynamic> json, Function(Map<String, dynamic>) create) =>
BaseResponse(
message: json["message"],
success: json["success"],
timestamp: json["timestamp"],
data: json["data"] is int
? null
: create(json["data"] is List ? json : json['data'] ?? {}),
);

Map<String, dynamic> toJson() => {
"message": message,
"timestamp": timestamp,
"success": success,
"data": data!.toJson(),
};
}

abstract class Serializable {
Map<String, dynamic> toJson();
}
import 'package:equatable/equatable.dart';

class ErrorResponse extends Equatable {
const ErrorResponse({
this.responseCode,
this.responseDescription,
});

final String? responseCode;
final String? responseDescription;

@override
List<Object> get props => [responseDescription!, responseCode!];
}class LoginRequest {
final String emailAddress;
final String password;

LoginRequest({
required this.emailAddress,
required this.password,
});

Map<String, dynamic> toJson() {
return {
"email_address": emailAddress,
"password": password,
};
}
}import 'package:d_pos/features/data/models/common/base_response.dart';

class OrderItem extends Serializable{
final String foodMenuId;
final String menuName;
final int quantity;
final double unitPrice;
final double totalPrice;
final String itemNote;

OrderItem({
required this.foodMenuId,
required this.menuName,
required this.quantity,
required this.unitPrice,
required this.totalPrice,
required this.itemNote,
});

factory OrderItem.fromJson(Map<String, dynamic> json) {
final qty = int.tryParse(json['qty'] ?? '0') ?? 0;
final price =
double.tryParse(json['menu_unit_price'] ?? '0') ?? 0;

    return OrderItem(
      foodMenuId: json['food_menu_id'] ?? '',
      menuName: json['menu_name'] ?? '',
      quantity: qty,
      unitPrice: price,
      totalPrice: qty * price,
      itemNote: json['item_note'] ?? '',
    );
}

@override
Map<String, dynamic> toJson() {
// TODO: implement toJson
throw UnimplementedError();
}
}
class PlaceOrderRequest {
final String saleNo;
final String randomCode;
final String customerId;
final String customerName;
final String status;
final int totalItemsInCart;
final int totalItemsInCartQty;
final double subTotal;
final double totalPayable;
final String saleDate;
final String dateTime;
final String orderTime;
final int orderType;
final List<OrderItemRequest> items;

PlaceOrderRequest({
required this.saleNo,
required this.randomCode,
required this.customerId,
required this.customerName,
required this.status,
required this.totalItemsInCart,
required this.totalItemsInCartQty,
required this.subTotal,
required this.totalPayable,
required this.saleDate,
required this.dateTime,
required this.orderTime,
required this.orderType,
required this.items,
});

Map<String, dynamic> toJson() {
return {
"sale_no": saleNo,
"random_code": randomCode,
"customer_id": customerId,
"customer_name": customerName,
"status": status,
"total_items_in_cart": totalItemsInCart,
"total_items_in_cart_qty": totalItemsInCartQty,
"sub_total": subTotal,
"total_payable": totalPayable,
"sale_date": saleDate,
"date_time": dateTime,
"order_time": orderTime,
"order_type": orderType,
"items": items.map((x) => x.toJson()).toList(),
};
}
}

class OrderItemRequest {
final int foodMenuId;
final String menuName;
final double menuUnitPrice;
final int qty;
final String modifiersId;
final String modifiersName;
final String modifiersPrice;
final ModifiersJsonData? modifiersJson;

OrderItemRequest({
required this.foodMenuId,
required this.menuName,
required this.menuUnitPrice,
required this.qty,
this.modifiersId = "",
this.modifiersName = "",
this.modifiersPrice = "",
this.modifiersJson,
});

Map<String, dynamic> toJson() {
dynamic modifiersPayload;

    if (modifiersJson == null) {
      modifiersPayload = [];
    } else if (modifiersJson!.modifiers.isEmpty &&
        modifiersJson!.itemNote.isEmpty) {
      modifiersPayload = [];
    } else {
      modifiersPayload = modifiersJson!.toJson();
    }
    return {
      "food_menu_id": foodMenuId,
      "menu_name": menuName,
      "menu_unit_price": menuUnitPrice,
      "qty": qty,
      "modifiers_id": modifiersId,
      "modifiers_name": modifiersName,
      "modifiers_price": modifiersPrice,
      "modifiers_json": modifiersPayload,
    };
}
}

class ModifiersJsonData {
final String itemNote;
final List<ModifierItem> modifiers;

ModifiersJsonData({required this.itemNote, required this.modifiers});

Map<String, dynamic> toJson() {
return {
"item_note": itemNote,
"modifiers": modifiers.map((x) => x.toJson()).toList(),
};
}
}

class ModifierItem {
final int modifierId;
final String modifierName;
final double modifierPrice;
final int totalQty;
final double totalPrice;
final List<ModifierUnit> units;

ModifierItem({
required this.modifierId,
required this.modifierName,
required this.modifierPrice,
required this.totalQty,
required this.totalPrice,
required this.units,
});

Map<String, dynamic> toJson() {
return {
"modifier_id": modifierId,
"modifier_name": modifierName,
"modifier_price": modifierPrice,
"total_qty": totalQty,
"total_price": totalPrice,
"units": units.map((x) => x.toJson()).toList(),
};
}
}

class ModifierUnit {
final int unit;
final int qty;
final double linePrice;

ModifierUnit({
required this.unit,
required this.qty,
required this.linePrice,
});

Map<String, dynamic> toJson() {
return {"unit": unit, "qty": qty, "line_price": linePrice};
}
}
// To parse this JSON data, do
//
//     final errorResponseModel = errorResponseModelFromJson(jsonString);

import 'dart:convert';

import '../common/error_response.dart';

ErrorResponseModel errorResponseModelFromJson(String str) =>
ErrorResponseModel.fromJson(json.decode(str));

String errorResponseModelToJson(ErrorResponseModel data) =>
json.encode(data.toJson());

class ErrorResponseModel extends ErrorResponse {
const ErrorResponseModel({
this.errorCode,
this.title,
this.errorDescription,
});

final String? errorCode;
final String? title;
final String? errorDescription;

factory ErrorResponseModel.fromJson(Map<String, dynamic> json) =>
ErrorResponseModel(
errorCode: json['errorCode']?.toString() ?? json['code']?.toString(),
title: json['error']?.toString() ?? json['title']?.toString(),
errorDescription: json['errorDescription'] ?? json['message'] ?? json['error'],
);

Map<String, dynamic> toJson() => {
"errorCode": errorCode,
"errorDescription": errorDescription,
};
}
// To parse this JSON data, do
//
//     final loginResponse = loginResponseFromJson(jsonString);

import 'dart:convert';

import 'package:d_pos/features/data/models/common/base_response.dart';

LoginResponse loginResponseFromJson(String str) => LoginResponse.fromJson(json.decode(str));

String loginResponseToJson(LoginResponse data) => json.encode(data.toJson());

class LoginResponse extends Serializable{
final String? message;
final String accessToken;
final String? tokenType;
final User user;

LoginResponse({
this.message,
required this.accessToken,
this.tokenType,
required this.user,
});

factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
message: json["message"],
accessToken: json["access_token"],
tokenType: json["token_type"],
user: User.fromJson(json['user'] ?? {}),
);

Map<String, dynamic> toJson() => {
"message": message,
"access_token": accessToken,
"token_type": tokenType,
"user": user?.toJson(),
};
}

class User extends Serializable{
final int id;
final String? fullName;
final String? phone;
final String? emailAddress;
final String? designation;
final String? willLogin;
final String? role;
final int? outletId;
final String? outlets;
final String? kitchens;
final int? companyId;
final dynamic accountCreationDate;
final String? language;
final dynamic lastLogin;
final int? createdId;
final String? activeStatus;
final String? delStatus;
final DateTime? createdDate;
final dynamic question;
final dynamic answer;
final String? loginPin;
final int? orderReceivingId;
final int? roleId;
final dynamic emailVerifiedAt;
final dynamic createdAt;
final dynamic updatedAt;
final Outlet? outlet;

User({
required this.id,
this.fullName,
this.phone,
this.emailAddress,
this.designation,
this.willLogin,
this.role,
this.outletId,
this.outlets,
this.kitchens,
this.companyId,
this.accountCreationDate,
this.language,
this.lastLogin,
this.createdId,
this.activeStatus,
this.delStatus,
this.createdDate,
this.question,
this.answer,
this.loginPin,
this.orderReceivingId,
this.roleId,
this.emailVerifiedAt,
this.createdAt,
this.updatedAt,
this.outlet,
});

factory User.fromJson(Map<String, dynamic> json) => User(
id: json["id"],
fullName: json["full_name"],
phone: json["phone"],
emailAddress: json["email_address"],
designation: json["designation"],
willLogin: json["will_login"],
role: json["role"],
outletId: json["outlet_id"],
outlets: json["outlets"],
kitchens: json["kitchens"],
companyId: json["company_id"],
accountCreationDate: json["account_creation_date"],
language: json["language"],
lastLogin: json["last_login"],
createdId: json["created_id"],
activeStatus: json["active_status"],
delStatus: json["del_status"],
createdDate: json["created_date"] == null ? null : DateTime.parse(json["created_date"]),
question: json["question"],
answer: json["answer"],
loginPin: json["login_pin"],
orderReceivingId: json["order_receiving_id"],
roleId: json["role_id"],
emailVerifiedAt: json["email_verified_at"],
createdAt: json["created_at"],
updatedAt: json["updated_at"],
outlet: json["outlet"] == null ? null : Outlet.fromJson(json["outlet"]),
);

Map<String, dynamic> toJson() => {
"id": id,
"full_name": fullName,
"phone": phone,
"email_address": emailAddress,
"designation": designation,
"will_login": willLogin,
"role": role,
"outlet_id": outletId,
"outlets": outlets,
"kitchens": kitchens,
"company_id": companyId,
"account_creation_date": accountCreationDate,
"language": language,
"last_login": lastLogin,
"created_id": createdId,
"active_status": activeStatus,
"del_status": delStatus,
"created_date": "${createdDate!.year.toString().padLeft(4, '0')}-${createdDate!.month.toString().padLeft(2, '0')}-${createdDate!.day.toString().padLeft(2, '0')}",
"question": question,
"answer": answer,
"login_pin": loginPin,
"order_receiving_id": orderReceivingId,
"role_id": roleId,
"email_verified_at": emailVerifiedAt,
"created_at": createdAt,
"updated_at": updatedAt,
"outlet": outlet?.toJson(),
};
}

class Outlet {
final int? id;
final String? outletName;
final String? outletCode;
final String? address;
final String? phone;
final String? email;
final int? defaultWaiter;
final int? companyId;
final String? foodMenus;
final String? foodMenuPrices;
final String? deliveryPrice;
final String? hasKitchen;
final String? activeStatus;
final String? delStatus;
final int? onlineSelfOrderReceivingId;
final DateTime? createdDate;
final int? onlineOrderModule;
final dynamic availableOnlineFoods;
final dynamic thumbImgs;
final dynamic largeImgs;
final dynamic exploreSectionItems;
final int? onlineOrderReceivingId;
final int? reservationOrderReceivingId;

Outlet({
this.id,
this.outletName,
this.outletCode,
this.address,
this.phone,
this.email,
this.defaultWaiter,
this.companyId,
this.foodMenus,
this.foodMenuPrices,
this.deliveryPrice,
this.hasKitchen,
this.activeStatus,
this.delStatus,
this.onlineSelfOrderReceivingId,
this.createdDate,
this.onlineOrderModule,
this.availableOnlineFoods,
this.thumbImgs,
this.largeImgs,
this.exploreSectionItems,
this.onlineOrderReceivingId,
this.reservationOrderReceivingId,
});

factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
id: json["id"],
outletName: json["outlet_name"],
outletCode: json["outlet_code"],
address: json["address"],
phone: json["phone"],
email: json["email"],
defaultWaiter: json["default_waiter"],
companyId: json["company_id"],
foodMenus: json["food_menus"],
foodMenuPrices: json["food_menu_prices"],
deliveryPrice: json["delivery_price"],
hasKitchen: json["has_kitchen"],
activeStatus: json["active_status"],
delStatus: json["del_status"],
onlineSelfOrderReceivingId: json["online_self_order_receiving_id"],
createdDate: json["created_date"] == null ? null : DateTime.parse(json["created_date"]),
onlineOrderModule: json["online_order_module"],
availableOnlineFoods: json["available_online_foods"],
thumbImgs: json["thumb_imgs"],
largeImgs: json["large_imgs"],
exploreSectionItems: json["explore_section_items"],
onlineOrderReceivingId: json["online_order_receiving_id"],
reservationOrderReceivingId: json["reservation_order_receiving_id"],
);

Map<String, dynamic> toJson() => {
"id": id,
"outlet_name": outletName,
"outlet_code": outletCode,
"address": address,
"phone": phone,
"email": email,
"default_waiter": defaultWaiter,
"company_id": companyId,
"food_menus": foodMenus,
"food_menu_prices": foodMenuPrices,
"delivery_price": deliveryPrice,
"has_kitchen": hasKitchen,
"active_status": activeStatus,
"del_status": delStatus,
"online_self_order_receiving_id": onlineSelfOrderReceivingId,
"created_date": "${createdDate!.year.toString().padLeft(4, '0')}-${createdDate!.month.toString().padLeft(2, '0')}-${createdDate!.day.toString().padLeft(2, '0')}",
"online_order_module": onlineOrderModule,
"available_online_foods": availableOnlineFoods,
"thumb_imgs": thumbImgs,
"large_imgs": largeImgs,
"explore_section_items": exploreSectionItems,
"online_order_receiving_id": onlineOrderReceivingId,
"reservation_order_receiving_id": reservationOrderReceivingId,
};
}
import 'package:equatable/equatable.dart';

import '../pos_models.dart';

class MainScreenResponse extends Equatable {
final WaiterModel waiter;
final List<ModifierModel> modifiers;
final List<CategoryModel> categories;
final List<ProductModel> products;

const MainScreenResponse({
required this.waiter,
required this.modifiers,
required this.categories,
required this.products,
});

factory MainScreenResponse.fromJson(Map<String, dynamic> json) {
return MainScreenResponse(
waiter: WaiterModel.fromJson(json['waiter']),
modifiers: (json['modifiers'] as List)
.map((i) => ModifierModel.fromJson(i))
.toList(),
categories: (json['categories'] as List)
.map((i) => CategoryModel.fromJson(i))
.toList(),
products: (json['products'] as List)
.map((i) => ProductModel.fromJson(i))
.toList(),
);
}
MainScreenResponse copyWith({
WaiterModel? waiter,
List<ModifierModel>? modifiers,
List<CategoryModel>? categories,
List<ProductModel>? products,
}) {
return MainScreenResponse(
waiter: waiter ?? this.waiter,
modifiers: modifiers ?? this.modifiers,
categories: categories ?? this.categories,
products: products ?? this.products,
);
}
@override
List<Object?> get props => [waiter, modifiers, categories, products];
}

class WaiterModel extends Equatable {
final int id;
final String fullName;
final String emailAddress;

const WaiterModel({
required this.id,
required this.fullName,
required this.emailAddress,
});

factory WaiterModel.fromJson(Map<String, dynamic> json) {
return WaiterModel(
id: json['id'],
fullName: json['full_name'],
emailAddress: json['email_address'],
);
}

@override
List<Object?> get props => [id, fullName, emailAddress];
}
class KitchenOrderResponse {
final String message;
final int kitchenSaleId;
final String saleNo;
final String randomCode;
final KotPrintResponse? kotPrint;

const KitchenOrderResponse({
required this.message,
required this.kitchenSaleId,
required this.saleNo,
required this.randomCode,
this.kotPrint,
});

factory KitchenOrderResponse.fromJson(Map<String, dynamic> json) {
return KitchenOrderResponse(
message: json["message"] ?? "",
kitchenSaleId: json["kitchen_sale_id"] ?? 0,
saleNo: json["sale_no"] ?? "",
randomCode: json["random_code"] ?? "",
kotPrint: json["kot_print"] != null
? KotPrintResponse.fromJson(json["kot_print"])
: null,
);
}
}

class KotPrintResponse {
final bool ok;
final int status;
final KotBodyResponse? body;

KotPrintResponse({required this.ok, required this.status, this.body});

factory KotPrintResponse.fromJson(Map<String, dynamic> json) {
return KotPrintResponse(
ok: json["ok"] ?? false,
status: json["status"] ?? 0,
body: json["body"] != null ? KotBodyResponse.fromJson(json["body"]) : null,
);
}
}

class KotBodyResponse {
final String status;
final String printer;

KotBodyResponse({required this.status, required this.printer});

factory KotBodyResponse.fromJson(Map<String, dynamic> json) {
return KotBodyResponse(
status: json["status"] ?? "",
printer: json["printer"] ?? "",
);
}
}class PrintResponseModel {
final String message;
final String printUrl;
final PrinterDetails? printerResponse;

PrintResponseModel({
required this.message,
required this.printUrl,
this.printerResponse,
});

factory PrintResponseModel.fromJson(Map<String, dynamic> json) {
return PrintResponseModel(
message: json['message'] ?? "Print request sent",
printUrl: json['print_url'] ?? "",
printerResponse: json['printer_response'] != null
? PrinterDetails.fromJson(json['printer_response'])
: null,
);
}
}

class PrinterDetails {
final String status;
final String printer;
final String ip;
final int port;

PrinterDetails({
required this.status,
required this.printer,
required this.ip,
required this.port,
});

factory PrinterDetails.fromJson(Map<String, dynamic> json) {
return PrinterDetails(
status: json['status'] ?? "",
printer: json['printer'] ?? "",
ip: json['ip'] ?? "",
port: json['port'] ?? 9100,
);
}
}import '../../models/common/base_response.dart';

class RunningOrderData extends Serializable{
final List<RunningOrderModel> runningOrders;

RunningOrderData({required this.runningOrders});

factory RunningOrderData.fromJson(Map<String, dynamic> json) {
return RunningOrderData(
runningOrders: (json['running_orders'] as List?)
?.map((e) => RunningOrderModel.fromJson(e))
.toList() ??
[],
);
}

@override
Map<String, dynamic> toJson() {
throw UnimplementedError();
}
}

class RunningOrderModel {
final int id;
final String saleNo;
final String customerName;
final String status;
final double totalPayable;
final String orderTime;
final String tableText;
final List<RunningOrderDetailModel> details;

RunningOrderModel({
required this.id,
required this.saleNo,
required this.customerName,
required this.status,
required this.totalPayable,
required this.orderTime,
required this.tableText,
required this.details,
});

factory RunningOrderModel.fromJson(Map<String, dynamic> json) {
return RunningOrderModel(
id: json['id'] ?? 0,
saleNo: json['sale_no'] ?? '',
customerName: json['customer_id'] ?? 'Unknown', // JSON shows customer_id holds the name "nnew oder"
status: json['status'] ?? 'Unknown',
totalPayable: double.tryParse(json['total_payable']?.toString() ?? '0') ?? 0.0,
orderTime: json['order_time'] ?? '',
tableText: json['orders_table_text'] ?? '',
details: (json['details'] as List?)
?.map((e) => RunningOrderDetailModel.fromJson(e))
.toList() ??
[],
);
}
}

class RunningOrderDetailModel {
final int id;
final String menuName;
final int qty;
final double price;

RunningOrderDetailModel({
required this.id,
required this.menuName,
required this.qty,
required this.price,
});

factory RunningOrderDetailModel.fromJson(Map<String, dynamic> json) {
return RunningOrderDetailModel(
id: json['id'] ?? 0,
menuName: json['menu_name'] ?? '',
qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
price: double.tryParse(json['menu_price_with_discount']?.toString() ?? '0') ?? 0.0,
);
}
}// To parse this JSON data, do
//
//     final sendOtpResponse = sendOtpResponseFromJson(jsonString);

import 'dart:convert';

import '../common/base_response.dart';

SendOtpResponse sendOtpResponseFromJson(String str) => SendOtpResponse.fromJson(json.decode(str));

String sendOtpResponseToJson(SendOtpResponse data) => json.encode(data.toJson());

class SendOtpResponse extends Serializable{
final String? phoneNumber;
final String? message;
final String? otp;
final bool? customerExists;
final int? expirySeconds;
final int? maxInvalidAttempts;

SendOtpResponse({
this.phoneNumber,
this.message,
this.otp,
this.customerExists,
this.expirySeconds,
this.maxInvalidAttempts,
});

factory SendOtpResponse.fromJson(Map<String, dynamic> json) => SendOtpResponse(
phoneNumber: json["phoneNumber"],
message: json["message"],
otp: json["otp"],
customerExists: json["customerExists"],
expirySeconds: json["expirySeconds"],
maxInvalidAttempts: json["maxInvalidAttempts"],
);

@override
Map<String, dynamic> toJson() => {
"phoneNumber": phoneNumber,
"message": message,
"otp": otp,
"customerExists": customerExists,
"expirySeconds": expirySeconds,
"maxInvalidAttempts": maxInvalidAttempts,
};
}
// To parse this JSON data, do
//
//     final verifyOtpResponse = verifyOtpResponseFromJson(jsonString);

import 'dart:convert';


import '../common/base_response.dart';

VerifyOtpResponse verifyOtpResponseFromJson(String str) => VerifyOtpResponse.fromJson(json.decode(str));

String verifyOtpResponseToJson(VerifyOtpResponse data) => json.encode(data.toJson());

class VerifyOtpResponse extends Serializable{
final String? token;
final String? refreshToken;
final bool? customerExists;
final Customer? customer;
final bool? profileComplete;

VerifyOtpResponse({
this.token,
this.refreshToken,
this.customerExists,
this.customer,
this.profileComplete,
});

factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) => VerifyOtpResponse(
token: json["token"],
refreshToken: json["refreshToken"],
customerExists: json["customerExists"],
customer: json["customer"] == null ? null : Customer.fromJson(json["customer"]),
profileComplete: json["profileComplete"],
);

@override
Map<String, dynamic> toJson() => {
"token": token,
"refreshToken": refreshToken,
"customerExists": customerExists,
"customer": customer?.toJson(),
"profileComplete": profileComplete,
};
}


class Customer {
final int? id;
final String? firstName;
final String? lastName;
final String? email;
final String? phoneNumber;
final String? gender;
final int? completedAppointments;
final String? lastVisit;
final DateTime? memberSince;
final bool? profileComplete;
final dynamic profileImageUrl;

Customer({
this.id,
this.firstName,
this.lastName,
this.email,
this.phoneNumber,
this.gender,
this.completedAppointments,
this.lastVisit,
this.memberSince,
this.profileComplete,
this.profileImageUrl,
});

factory Customer.fromJson(Map<String, dynamic> json) => Customer(
id: json["id"],
firstName: json["firstName"],
lastName: json["lastName"],
email: json["email"],
phoneNumber: json["phoneNumber"],
gender: json["gender"],
completedAppointments: json["completedAppointments"],
lastVisit: json["lastVisit"],
memberSince: json["memberSince"] == null ? null : DateTime.parse(json["memberSince"]),
profileComplete: json["profileComplete"],
profileImageUrl: json["profileImageUrl"],
);

Map<String, dynamic> toJson() => {
"id": id,
"firstName": firstName,
"lastName": lastName,
"email": email,
"phoneNumber": phoneNumber,
"gender": gender,
"completedAppointments": completedAppointments,
"lastVisit": lastVisit,
"memberSince": memberSince?.toIso8601String(),
"profileComplete": profileComplete,
"profileImageUrl": profileImageUrl,
};
}
import 'package:equatable/equatable.dart';

// ── Sentinel wrapper so copyWith can explicitly set nullable fields to null ──
class _Absent {
const _Absent();
}

const _absent = _Absent();

class CategoryModel extends Equatable {
final int id;
final bool showLocalImage;
final String name;
final String? imageUrl;
final String? localPath;

const CategoryModel({
required this.id,
required this.name,
this.showLocalImage = true,
this.imageUrl,
this.localPath,
});

factory CategoryModel.fromJson(Map<String, dynamic> json) {
return CategoryModel(
id: json['id'] as int,
name: json['category_name'] ?? json['name'],
imageUrl: json['category_image'] as String?,
localPath: json['localPath'] as String?,
showLocalImage: json['showLocalImage'] as bool? ?? true,
);
}

/// Pass [localPath] = null explicitly to clear it.
/// Omit [localPath] entirely (or pass the sentinel) to keep the existing value.
CategoryModel copyWith({
int? id,
String? name,
String? imageUrl,
bool? showLocalImage,
Object? localPath = _absent, // ← sentinel pattern
}) {
return CategoryModel(
id: id ?? this.id,
name: name ?? this.name,
imageUrl: imageUrl ?? this.imageUrl,
// If caller passed a value (including null) use it; otherwise keep existing
localPath: localPath is _Absent ? this.localPath : localPath as String?,
showLocalImage: showLocalImage ?? this.showLocalImage,
);
}

Map<String, dynamic> toJson() => {
'id': id,
'name': name,
'localPath': localPath,
'imageUrl': imageUrl,
'showLocalImage': showLocalImage,
};

@override
List<Object?> get props => [id, name, imageUrl, localPath, showLocalImage];

// ── Filter out unwanted categories (e.g., empty or staff categories) ──
static List<CategoryModel> filterValidCategories(List<CategoryModel> categories) {
const List<String> excludedCategories = [
'staff food?',
'staff food',
];

    return categories
        .where((category) => !excludedCategories.contains(category.name.toLowerCase()))
        .toList();
}
}

class ProductModel extends Equatable {
final int id;
final String name;
final String? alternativeName;
final double price;
final bool showLocalImage;
final int categoryId;
final String? imageUrl;
final String? localPath;

const ProductModel({
required this.id,
this.showLocalImage = true,
required this.name,
required this.alternativeName,
required this.price,
required this.categoryId,
this.imageUrl,
this.localPath,
});

factory ProductModel.fromJson(Map<String, dynamic> json) {
final String? rawPhoto = json['photo'] as String?;
final String? fullImageUrl = (rawPhoto != null && rawPhoto.isNotEmpty)
? rawPhoto.replaceAll('temp', 'temp')
: null;
return ProductModel(
id: json['id'] as int,
alternativeName: json['alternative_name'],
name: (json['name'] ?? 'Unknown') as String,
price: (json['sale_price'] ?? json['price'] ?? 0.0).toDouble(),
categoryId: json['category_id'] ?? 0,
imageUrl: fullImageUrl,
localPath: json['localPath'] as String?,
showLocalImage: json['showLocalImage'] as bool? ?? true,
);
}

Map<String, dynamic> toJson() => {
'id': id,
'name': name,
'alternative_name': alternativeName,
'price': price,
'category_id': categoryId,
'photo': imageUrl,
'localPath': localPath,
'showLocalImage': showLocalImage,
};

/// Pass [localPath] = null explicitly to clear it.
/// Omit [localPath] entirely (or pass the sentinel) to keep the existing value.
ProductModel copyWith({
String? name,
bool? showLocalImage,
double? price,
int? categoryId,
Object? localPath = _absent, // ← sentinel pattern
}) {
return ProductModel(
id: id,
alternativeName: alternativeName,
name: name ?? this.name,
price: price ?? this.price,
showLocalImage: showLocalImage ?? this.showLocalImage,
categoryId: categoryId ?? this.categoryId,
imageUrl: imageUrl,
localPath: localPath is _Absent ? this.localPath : localPath as String?,
);
}

@override
List<Object?> get props =>
[id, name, alternativeName, price, categoryId, imageUrl, localPath, showLocalImage];
}

class ModifierModel extends Equatable {
final int id;
final String name;
final double price;

const ModifierModel({
required this.id,
required this.name,
required this.price,
});

factory ModifierModel.fromJson(Map<String, dynamic> json) {
return ModifierModel(
id: json['id'],
name: json['name'] ?? "Modifier",
price: double.tryParse(json['price'].toString()) ?? 0.0,
);
}

@override
List<Object?> get props => [id, name, price];
}

class CartItem extends Equatable {
final String uuid;
final ProductModel product;
final int quantity;
final List<ModifierModel> modifiers;
final String note;

const CartItem({
required this.uuid,
required this.product,
required this.quantity,
this.modifiers = const [],
this.note = '',
});

double get total {
double modifiersTotal = modifiers.fold(0, (sum, mod) => sum + mod.price);
return (product.price + modifiersTotal) * quantity;
}

CartItem copyWith({
String? uuid,
ProductModel? product,
int? quantity,
List<ModifierModel>? modifiers,
String? note,
}) {
return CartItem(
uuid: uuid ?? this.uuid,
product: product ?? this.product,
quantity: quantity ?? this.quantity,
modifiers: modifiers ?? this.modifiers,
note: note ?? this.note,
);
}

@override
List<Object?> get props => [uuid, product, quantity, modifiers, note];
}import 'dart:convert';
import 'dart:io';

import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';
import 'package:d_pos/features/data/models/pos_models.dart';
import 'package:d_pos/utils/app_constants.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/network_info.dart';
import '../../../core/service/image_downloader_service.dart';
import '../../../error/exceptions.dart';
import '../../../error/failures.dart';
import '../../domain/repositories/repository.dart';
import '../data_sources/remote_data_sources.dart';
import '../models/common/base_response.dart';
import '../models/request/place_order_request.dart';
import '../models/response/error_response_model.dart';
import '../models/response/main_screen_response.dart';
import '../models/response/place_order_response.dart';
import '../models/response/print_response_model.dart';
import '../models/response/running_orders_response_model.dart';

class RepositoryImpl implements Repository {
final RemoteDataSource remoteDataSource;
final NetworkInfo networkInfo;

RepositoryImpl({
required this.remoteDataSource,
required this.networkInfo,
});

MainScreenResponse? _cachedMainScreenData;

static const String _categoriesKey = 'local_categories';
static const String _productsKey = 'local_products';


Future<List<CategoryModel>?> _loadLocalCategories() async {
final prefs = await SharedPreferences.getInstance();
final raw = prefs.getString(_categoriesKey);
if (raw == null) return null;
final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
return decoded
.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
.toList();
}

Future<void> _saveLocalCategories(List<CategoryModel> categories) async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString(
_categoriesKey,
jsonEncode(categories.map((c) => c.toJson()).toList()),
);
}

int _nextLocalId(List<CategoryModel> categories) {
if (categories.isEmpty) return 1;
return categories.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
}


Future<List<ProductModel>?> _loadLocalProducts() async {
final prefs = await SharedPreferences.getInstance();
final raw = prefs.getString(_productsKey);
if (raw == null) return null;
final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
return decoded.map((e) => ProductModel.fromJson(e)).toList();
}

Future<void> _saveLocalProducts(List<ProductModel> products) async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString(
_productsKey,
jsonEncode(products.map((p) => p.toJson()).toList()),
);
}


@override
Future<Either<Failure, LoginResponse>> login(
LoginRequest loginRequest) async {
if (await networkInfo.isConnected) {
try {
final response = await remoteDataSource.login(loginRequest);
if (response.accessToken.isNotEmpty) {
AppConstants.accessToken = response.accessToken;
}
AppConstants.userId = response.user.id;
return Right(response);
} on ServerException catch (e) {
return Left(ServerFailure(e.errorResponseModel));
} on UnAuthorizedException catch (e) {
return Left(AuthorizedFailure(e.errorResponseModel));
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
} else {
return Left(ConnectionFailure());
}
}

MainScreenResponse _mockMainScreenData() {
return const MainScreenResponse(
waiter: WaiterModel(
id: 1,
fullName: 'Demo Waiter',
emailAddress: 'demo@example.com',
),
modifiers: [
ModifierModel(id: 1, name: 'Extra Cheese', price: 1.5),
ModifierModel(id: 2, name: 'Spicy', price: 0.0),
ModifierModel(id: 3, name: 'No Onion', price: 0.0),
],
categories: [
CategoryModel(id: 1, name: 'Beverages'),
CategoryModel(id: 2, name: 'Burgers'),
CategoryModel(id: 3, name: 'Desserts'),
],
products: [
ProductModel(id: 1, name: 'Iced Coffee', alternativeName: null, price: 3.5, categoryId: 1),
ProductModel(id: 2, name: 'Fresh Juice', alternativeName: null, price: 2.5, categoryId: 1),
ProductModel(id: 3, name: 'Cheese Burger', alternativeName: null, price: 6.0, categoryId: 2),
ProductModel(id: 4, name: 'Chicken Burger', alternativeName: null, price: 5.5, categoryId: 2),
ProductModel(id: 5, name: 'Chocolate Cake', alternativeName: null, price: 4.0, categoryId: 3),
],
);
}
@override
Future<Either<Failure, MainScreenResponse>> getMainScreenData() async {
if (AppConstants.useMockData) {
return Right(_mockMainScreenData());
}

    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.getMainScreenData();

        final localCats = await _loadLocalCategories() ?? [];
        final List<CategoryModel> syncedCats = [];
        final serverCatIds = response.categories.map((c) => c.id).toSet();

        for (var serverCat in response.categories) {
          final localMatch =
              localCats.where((c) => c.id == serverCat.id).firstOrNull;
          String? finalPath = localMatch?.localPath;

          if ((finalPath == null || finalPath.isEmpty) &&
              serverCat.imageUrl != null &&
              serverCat.imageUrl!.isNotEmpty) {
            finalPath = await ImageStorageService.downloadAndSaveImage(
              serverCat.imageUrl!,
              'cat_${serverCat.id}',
            );
          }

          syncedCats.add(serverCat.copyWith(
            localPath: finalPath,
            name: localMatch?.name ?? serverCat.name,
            showLocalImage: localMatch?.showLocalImage ?? true,
          ));
        }

        syncedCats
            .addAll(localCats.where((c) => !serverCatIds.contains(c.id)));
        
        final filteredCats = CategoryModel.filterValidCategories(syncedCats);
        
        await _saveLocalCategories(filteredCats);

        final localProds = await _loadLocalProducts() ?? [];
        final List<ProductModel> syncedProds = [];
        final serverProdIds = response.products.map((p) => p.id).toSet();

        for (var serverProd in response.products) {
          final localMatch =
              localProds.where((p) => p.id == serverProd.id).firstOrNull;
          String? finalPath = localMatch?.localPath;

          if ((finalPath == null || finalPath.isEmpty) &&
              serverProd.imageUrl != null &&
              serverProd.imageUrl!.isNotEmpty) {
            finalPath = await ImageStorageService.downloadAndSaveImage(
              serverProd.imageUrl!,
              'prod_${serverProd.id}',
            );
          }

          syncedProds.add(serverProd.copyWith(
            localPath: finalPath,
            name: localMatch?.name ?? serverProd.name,
            showLocalImage: localMatch?.showLocalImage ?? true,
          ));
        }

        syncedProds
            .addAll(localProds.where((p) => !serverProdIds.contains(p.id)));
        await _saveLocalProducts(syncedProds);

        return Right(
            response.copyWith(categories: filteredCats, products: syncedProds));
      } catch (e) {
        return Left(
            ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
      }
    } else {
      return Left(ConnectionFailure());
    }
}


@override
Future<Either<Failure, BaseResponse<RunningOrderData>>> getRunningOrders(
int id) async {
if (await networkInfo.isConnected) {
try {
final response = await remoteDataSource.getRunningOrders(id);
return Right(response);
} on ServerException catch (e) {
return Left(ServerFailure(e.errorResponseModel));
} on UnAuthorizedException catch (e) {
return Left(AuthorizedFailure(e.errorResponseModel));
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
} else {
return Left(ConnectionFailure());
}
}


@override
Future<Either<Failure, PrintResponseModel>> printRunningOrder(
int orderId) async {
if (await networkInfo.isConnected) {
try {
final response = await remoteDataSource.printRunningOrder(orderId);
return Right(response);
} on ServerException catch (e) {
return Left(ServerFailure(e.errorResponseModel));
} on UnAuthorizedException catch (e) {
return Left(AuthorizedFailure(e.errorResponseModel));
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
} else {
return Left(ConnectionFailure());
}
}


@override
Future<Either<Failure, void>> logout() async {
try {
AppConstants.accessToken = '';
AppConstants.userId = null;
_cachedMainScreenData = null;
return const Right(null);
} catch (e) {
return Left(CacheFailure());
}
}


@override
Future<Either<Failure, KitchenOrderResponse>> submitKitchenOrder(
PlaceOrderRequest request) async {
if (await networkInfo.isConnected) {
try {
final response = await remoteDataSource.submitKitchenOrder(request);
return Right(response);
} on ServerException catch (e) {
return Left(ServerFailure(e.errorResponseModel));
} on UnAuthorizedException catch (e) {
return Left(AuthorizedFailure(e.errorResponseModel));
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
} else {
return Left(ConnectionFailure());
}
}


@override
Future<Either<Failure, List<CategoryModel>>> getCategories() async {
try {
final local = await _loadLocalCategories();
if (local != null) {
final filtered = CategoryModel.filterValidCategories(local);
return Right(filtered);
}

      if (_cachedMainScreenData != null) {
        final cats = _cachedMainScreenData!.categories;
        final filtered = CategoryModel.filterValidCategories(cats);
        await _saveLocalCategories(filtered);
        return Right(filtered);
      }

      return const Right([]);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
}

@override
Future<Either<Failure, CategoryModel>> createCategory(String name,
{String? imageBase64}) async {
try {
final current = await _loadLocalCategories() ?? [];
final newCat = CategoryModel(
id: _nextLocalId(current),
name: name,
localPath: imageBase64,
);
await _saveLocalCategories([...current, newCat]);
return Right(newCat);
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
}

@override
Future<Either<Failure, CategoryModel>> updateCategory(
int id,
String newName, {
String? imageBase64,
bool clearImage = false,
bool? showLocalImage,
}) async {
try {
final current = await _loadLocalCategories() ?? [];
final index = current.indexWhere((c) => c.id == id);
if (index == -1) {
return Left(ServerFailure(
ErrorResponseModel(errorDescription: 'Category not found')));
}

      String? finalPath = current[index].localPath;

      if (clearImage) {
        finalPath = null;
      } else if (imageBase64 != null && imageBase64.isNotEmpty) {
        finalPath = imageBase64;
      }

      final updated = current[index].copyWith(
        name: newName,
        localPath: finalPath,
        showLocalImage: showLocalImage ?? current[index].showLocalImage,
      );

      final list = List<CategoryModel>.from(current)..[index] = updated;
      await _saveLocalCategories(list);
      return Right(updated);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
}

@override
Future<Either<Failure, bool>> deleteCategory(int id) async {
try {
final current = await _loadLocalCategories() ?? [];
await _saveLocalCategories(current.where((c) => c.id != id).toList());
return const Right(true);
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
}


@override
Future<Either<Failure, List<ProductModel>>> getProducts() async {
try {
final local = await _loadLocalProducts();
return Right(local ?? []);
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
}

@override
Future<Either<Failure, ProductModel>> createProduct(
String name, String alternativeName, double price, int categoryId,
{String? imageBase64}) async {
try {
final current = await _loadLocalProducts() ?? [];
final newId = current.isEmpty
? 1
: current.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;

      String? finalPath;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        finalPath = await _saveBase64AsFile(imageBase64, 'prod_$newId');
      }

      final newProd = ProductModel(
        id: newId,
        alternativeName: alternativeName,
        name: name,
        price: price,
        categoryId: categoryId,
        localPath: finalPath,
      );

      await _saveLocalProducts([...current, newProd]);
      debugPrint(
          "PRODUCT CREATED: ${newProd.name} | PATH: ${newProd.localPath}");
      return Right(newProd);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
}

@override
Future<Either<Failure, ProductModel>> updateProduct(
int id,
String name,
double price,
int categoryId, {
String? imageBase64,
bool clearImage = false,
bool? showLocalImage,
}) async {
try {
final current = await _loadLocalProducts() ?? [];
final index = current.indexWhere((p) => p.id == id);
if (index == -1) {
return Left(ServerFailure(
ErrorResponseModel(errorDescription: "Product not found")));
}

      String? finalPath = current[index].localPath;

      if (clearImage) {
        finalPath = null;
      } else if (imageBase64 != null && imageBase64.isNotEmpty) {
        if (imageBase64.startsWith('/')) {
          finalPath = imageBase64;
        } else {
          finalPath =
          await _saveBase64AsFile(imageBase64, 'prod_updated_$id');
        }
      }

      final updated = current[index].copyWith(
        name: name,
        price: price,
        categoryId: categoryId,
        localPath: finalPath,
        showLocalImage: showLocalImage ?? current[index].showLocalImage,
      );

      final list = List<ProductModel>.from(current)..[index] = updated;
      await _saveLocalProducts(list);

      debugPrint(
          "PRODUCT UPDATED: ${updated.name} | PATH: ${updated.localPath} | SHOW_LOCAL: ${updated.showLocalImage}");
      return Right(updated);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
}

@override
Future<Either<Failure, bool>> deleteProduct(int id) async {
try {
final current = await _loadLocalProducts() ?? [];
await _saveLocalProducts(current.where((p) => p.id != id).toList());
return const Right(true);
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
}

@override
Future<Either<Failure, List<ProductModel>>> getLocalProducts() async {
try {
final local = await _loadLocalProducts();
return Right(local ?? []);
} catch (e) {
return Left(
ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
}
}


Future<String?> _saveBase64AsFile(String base64Str, String fileName) async {
try {
final cleanBase64 = base64Str.trim().split(',').last;
final directory = await getApplicationDocumentsDirectory();
final dirPath = p.join(directory.path, 'product_images');
await Directory(dirPath).create(recursive: true);
final filePath = p.join(dirPath, '$fileName.jpg');
final file = File(filePath);
await file.writeAsBytes(base64Decode(cleanBase64));
return filePath;
} catch (e) {
debugPrint("_saveBase64AsFile FAILED: $e");
return null;
}
}
}
import 'package:equatable/equatable.dart';

class CategoryModel extends Equatable {
final int id;
final String name;
final String? imageUrl;
final String? localPath;

const CategoryModel({
required this.id,
required this.name,
this.imageUrl,
this.localPath,
});

factory CategoryModel.fromJson(Map<String, dynamic> json) {
return CategoryModel(
id: (json['id'] ?? 0) as int,
name: (json['category_name'] ?? json['name'] ?? 'Unknown') as String,
imageUrl: json['category_image'] as String?,
localPath: json['localPath'] as String?,
);
}

Map<String, dynamic> toJson() => {
'id': id,
'name': name,
'imageUrl': imageUrl,
'localPath': localPath,
};

CategoryModel copyWith({
int? id,
String? name,
String? imageUrl,
String? localPath,
}) {
return CategoryModel(
id: id ?? this.id,
name: name ?? this.name,
imageUrl: imageUrl ?? this.imageUrl,
localPath: localPath ?? this.localPath,
);
}

@override
List<Object?> get props => [id, name, imageUrl, localPath];

@override
String toString() =>
'CategoryModel(id: $id, name: $name, imageUrl: $imageUrl, localPath: $localPath)';
}

import 'package:d_pos/features/data/models/pos_models.dart';
import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';
import 'package:dartz/dartz.dart';

import '../../../error/failures.dart';
import '../../data/models/common/base_response.dart';
import '../../data/models/request/place_order_request.dart';
import '../../data/models/response/main_screen_response.dart';
import '../../data/models/response/place_order_response.dart';
import '../../data/models/response/print_response_model.dart';
import '../../data/models/response/running_orders_response_model.dart';

abstract class Repository {
Future<Either<Failure, LoginResponse>> login(LoginRequest loginRequest);

Future<Either<Failure, MainScreenResponse>> getMainScreenData();

Future<Either<Failure, BaseResponse<RunningOrderData>>> getRunningOrders(
int id);

Future<Either<Failure, PrintResponseModel>> printRunningOrder(int orderId);

Future<Either<Failure, void>> logout();

Future<Either<Failure, KitchenOrderResponse>> submitKitchenOrder(
PlaceOrderRequest request);

Future<Either<Failure, List<CategoryModel>>> getCategories();

Future<Either<Failure, CategoryModel>> createCategory(
String name, {
String? imageBase64,
});

Future<Either<Failure, CategoryModel>> updateCategory(
int id,
String newName, {
String? imageBase64,
bool clearImage = false,
bool? showLocalImage,
});

Future<Either<Failure, bool>> deleteCategory(int id);

Future<Either<Failure, List<ProductModel>>> getProducts();

Future<Either<Failure, ProductModel>> createProduct(
String name,
String alternativeName,
double price,
int categoryId, {
String? imageBase64,
});

Future<Either<Failure, ProductModel>> updateProduct(
int id,
String name,
double price,
int categoryId, {
String? imageBase64,
bool clearImage = false,
bool? showLocalImage,
});

Future<Either<Failure, bool>> deleteProduct(int id);

Future<Either<Failure, List<ProductModel>>> getLocalProducts();
}import 'package:dartz/dartz.dart';

import '../../../../error/failures.dart';
import '../../data/models/pos_models.dart';
import '../repositories/repository.dart';

/// Wraps all category CRUD operations.
/// Uses the existing single [Repository] — no new repository needed.
///
/// Register in dependency_injection.dart:
///   sl.registerLazySingleton(() => CategoriesUseCase(sl()));
class CategoriesUseCase {
final Repository _repository;

const CategoriesUseCase(this._repository);

Future<Either<Failure, List<CategoryModel>>> getAll() {
return _repository.getCategories();
}

Future<Either<Failure, CategoryModel>> create(String name, {String? imageBase64}) {
return _repository.createCategory(name, imageBase64: imageBase64);
}

Future<Either<Failure, CategoryModel>> update(int id, String newName, {String? imageBase64, bool? showLocalImage}) {
return _repository.updateCategory(id, newName, imageBase64: imageBase64, showLocalImage : showLocalImage);
}

Future<Either<Failure, bool>> delete(int id) {
return _repository.deleteCategory(id);
}
}import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../../data/models/common/base_response.dart';
import '../../data/models/response/running_orders_response_model.dart';
import '../repositories/repository.dart';

class GetRunningOrdersUseCase {
final Repository repository;

GetRunningOrdersUseCase(this.repository);

Future<Either<Failure, BaseResponse<RunningOrderData>>> call(int id) async {
return await repository.getRunningOrders(id);
}
}import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';
import 'package:dartz/dartz.dart';

import '../../../../error/failures.dart';
import '../repositories/repository.dart';

class LoginUseCase {
final Repository repository;

LoginUseCase(this.repository);

Future<Either<Failure, LoginResponse>> call(
LoginRequest loginRequest,
) async => await repository.login(loginRequest);
}
import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../repositories/repository.dart';

class LogoutUseCase {
final Repository repository;

LogoutUseCase(this.repository);

Future<Either<Failure, void>> call() async {
return await repository.logout();
}
}import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../../data/models/response/main_screen_response.dart';
import '../repositories/repository.dart';

class MainScreenDataUseCase {
final Repository repository;

MainScreenDataUseCase(this.repository);

Future<Either<Failure, MainScreenResponse>> call() async {
return await repository.getMainScreenData();
}
}import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../../data/models/response/print_response_model.dart';
import '../repositories/repository.dart';

class PrintRunningOrderUseCase {
final Repository repository;

PrintRunningOrderUseCase(this.repository);

Future<Either<Failure, PrintResponseModel>> call(int orderId) async {
return await repository.printRunningOrder(orderId);
}
}import 'package:dartz/dartz.dart';

import '../../../error/failures.dart';
import '../../data/models/request/place_order_request.dart';
import '../../data/models/response/place_order_response.dart';
import '../repositories/repository.dart';

class SubmitKitchenOrderUseCase {
final Repository repository;

SubmitKitchenOrderUseCase(this.repository);

Future<Either<Failure, KitchenOrderResponse>> call(
PlaceOrderRequest params,
) async {
return await repository.submitKitchenOrder(params);
}
}
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../error/error_messages.dart';
import '../../../../error/failures.dart';
import '../../../../utils/app_constants.dart';
import '../../../../utils/app_strings.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../../data/models/request/login_request_model.dart';
import '../../../domain/use_cases/login_use_case.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
final LoginUseCase loginUseCase;
final LocalDataSource localDataSource;
LoginCubit({
required this.loginUseCase,
required this.localDataSource,
}) : super(LoginInitial());
static const branchName = 'pref_01';

Future<void> login(String emailAddress, String password) async {
emit(LoginLoading());
if (AppConstants.useMockData) {
await Future.delayed(const Duration(milliseconds: 300));
await saveBranch('Demo Branch');
emit(LoginSuccess(token: 'mock-token'));
return;
}
final request = LoginRequest(emailAddress: emailAddress, password: password);

    final loginResult = await loginUseCase(request);

    loginResult.fold(
          (failure) {
        if (failure is ConnectionFailure) {
          emit(LoginFailure(
              message: ErrorMessages().mapFailureToMessage(failure) ?? ""));
        } else if (failure is AuthorizedFailure) {
          emit(LoginFailure(
              message: AppStrings.unAuthorizedDes));
        } else if (failure is ServerFailure) {
          emit(LoginFailure(
              message: failure.errorResponse.errorDescription ??
                  AppStrings.somethingWentWrong));
        } else {
          emit(LoginFailure(
              message: AppStrings.somethingWentWrong));
        }
      },
          (response) async {
            saveBranch(response.user.outlet?.outletName ?? "");
        emit(LoginSuccess(token: response.accessToken));
      },
    );
}

Future<void> saveBranch(String branch) => localDataSource.saveBranch(branch);

Future<String> getBranch() => localDataSource.getBranch();

}abstract class LoginState {}

class LoginInitial extends LoginState {}
class LoginLoading extends LoginState {}
class LoginSyncing extends LoginState {}
class LoginSuccess extends LoginState {
final String token;
LoginSuccess({required this.token});
}
class LoginFailure extends LoginState {
final String message;
LoginFailure({required this.message});
}import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/use_cases/logout_use_case.dart';
import 'logout_state.dart';

class LogoutCubit extends Cubit<LogoutState> {
final LogoutUseCase logoutUseCase;

LogoutCubit({required this.logoutUseCase}) : super(LogoutInitial());

Future<void> logout() async {
emit(LogoutLoading());

    final result = await logoutUseCase();

    result.fold(
      (failure) => emit(LogoutError("Logout Failed")),
      (success) => emit(LogoutSuccess()),
    );
}
}
abstract class LogoutState {}
class LogoutInitial extends LogoutState {}
class LogoutLoading extends LogoutState {}
class LogoutSuccess extends LogoutState {}
class LogoutError extends LogoutState {
final String message;
LogoutError(this.message);
}
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/pos_models.dart';
import '../../../domain/use_cases/categories_use_case.dart';
import 'manage_categories_state.dart';

/// CategoriesUseCase contract (adapt to your domain layer):
/// - Future getCategories()
/// - Future createCategory(String name)
/// - Future updateCategory(int id, String name)
/// - Future deleteCategory(int id)

class CategoriesCubit extends Cubit<CategoriesState> {
final CategoriesUseCase categoriesUseCase;

List<CategoryModel> _categories = [];

CategoriesCubit({required this.categoriesUseCase})
: super(CategoriesInitial());

Future<void> fetchCategories() async {
emit(CategoriesLoading());

    final result = await categoriesUseCase.getAll();

    result.fold(
      (failure) => emit(CategoriesError(message: failure.toString())),
      (categories) {
        _categories = categories;
        emit(CategoriesLoaded(categories: _categories));
      },
    );
}

Future<void> createCategory(String name, {String? imageBase64}) async {
if (name.trim().isEmpty) return;

    emit(CategoryActionLoading(categories: _categories));

    final result = await categoriesUseCase.create(name.trim(), imageBase64: imageBase64);

    result.fold(
      (failure) => emit(
        CategoryActionError(
          categories: _categories,
          message: 'Failed to create category: ${failure.toString()}',
        ),
      ),
      (newCategory) {
        _categories = [..._categories, newCategory];
        emit(
          CategoryActionSuccess(
            categories: _categories,
            message: '"${newCategory.name}" added successfully.',
          ),
        );
      },
    );
}

Future<void> updateCategory(
int id,
String newName, {
String? imageBase64,
bool? showLocalImage,
}) async {
if (newName.trim().isEmpty) return;

    emit(CategoryActionLoading(categories: _categories));

    final result = await categoriesUseCase.update(
      id,
      newName.trim(),
      imageBase64: imageBase64,
      showLocalImage: showLocalImage,
    );

    result.fold(
          (failure) => emit(
        CategoryActionError(
          categories: _categories,
          message: 'Failed to update category: ${failure.toString()}',
        ),
      ),
          (updated) {
        _categories =
            _categories.map((c) => c.id == id ? updated : c).toList();
        emit(
          CategoryActionSuccess(
            categories: _categories,
            message: '"${updated.name}" updated successfully.',
          ),
        );
      },
    );
}

Future<void> deleteCategory(int id) async {
final target = _categories.firstWhere(
(c) => c.id == id,
orElse: () => CategoryModel(id: id, name: ''),
);

    emit(CategoryActionLoading(categories: _categories));

    final result = await categoriesUseCase.delete(id);

    result.fold(
      (failure) => emit(
        CategoryActionError(
          categories: _categories,
          message: 'Failed to delete category: ${failure.toString()}',
        ),
      ),
      (_) {
        _categories = _categories.where((c) => c.id != id).toList();
        emit(
          CategoryActionSuccess(
            categories: _categories,
            message: '"${target.name}" removed.',
          ),
        );
      },
    );
}
}import 'package:equatable/equatable.dart';
import '../../../data/models/pos_models.dart';

abstract class CategoriesState extends Equatable {
const CategoriesState();
@override
List<Object?> get props => [];
}

class CategoriesInitial extends CategoriesState {}

class CategoriesLoading extends CategoriesState {}

class CategoriesLoaded extends CategoriesState {
final List<CategoryModel> categories;
const CategoriesLoaded({required this.categories});

@override
List<Object?> get props => [categories];
}

class CategoriesError extends CategoriesState {
final String message;
const CategoriesError({required this.message});

@override
List<Object?> get props => [message];
}

class CategoryActionLoading extends CategoriesState {
final List<CategoryModel> categories;
const CategoryActionLoading({required this.categories});

@override
List<Object?> get props => [categories];
}

class CategoryActionSuccess extends CategoriesState {
final List<CategoryModel> categories;
final String message;
const CategoryActionSuccess({required this.categories, required this.message});

@override
List<Object?> get props => [categories, message];
}

class CategoryActionError extends CategoriesState {
final List<CategoryModel> categories;
final String message;
const CategoryActionError({required this.categories, required this.message});

@override
List<Object?> get props => [categories, message];
}import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/pos_models.dart';
import '../../../domain/repositories/repository.dart';
import 'manage_products_state.dart';

class ProductsCubit extends Cubit<ProductsState> {
final Repository repository;

ProductsCubit({required this.repository}) : super(ProductsInitial());

Future<void> fetchProducts() async {
emit(ProductsLoading());
final result = await repository.getProducts();
result.fold(
(failure) => emit(const ProductsError("Failed to load products")),
(products) => emit(ProductsLoaded(products)),
);
}

Future<void> createProduct(String name,String alternativeName, double price, int categoryId, {String? imageBase64}) async {
final currentProducts = state is ProductsLoaded ? (state as ProductsLoaded).products : <ProductModel>[];
emit(ProductActionLoading(currentProducts));

    final result = await repository.createProduct(name, alternativeName, price, categoryId, imageBase64: imageBase64);
    result.fold(
          (failure) => emit(ProductActionError(currentProducts, "Failed to create product")),
          (newProduct) {
        final updatedList = List<ProductModel>.from(currentProducts)..add(newProduct);
        emit(ProductActionSuccess(updatedList, "Product created successfully"));
      },
    );
}

Future<void> updateProduct(int id, String name, double price, int categoryId, {String? imageBase64, bool? showLocalImage, bool clearImage = false}) async {
final currentProducts = _getCurrentProducts();
emit(ProductActionLoading(currentProducts));

    final result = await repository.updateProduct(id, name, price, categoryId, imageBase64: imageBase64, showLocalImage : showLocalImage, clearImage : clearImage,   );
    result.fold(
          (failure) => emit(ProductActionError(currentProducts, "Failed to update product")),
          (updatedProduct) {
        final updatedList = currentProducts.map((p) => p.id == id ? updatedProduct : p).toList();
        emit(ProductActionSuccess(updatedList, "Product updated successfully"));
      },
    );
}

Future<void> deleteProduct(int id) async {
final currentProducts = _getCurrentProducts();
emit(ProductActionLoading(currentProducts));

    final result = await repository.deleteProduct(id);
    result.fold(
          (failure) => emit(ProductActionError(currentProducts, "Failed to delete product")),
          (_) {
        final updatedList = currentProducts.where((p) => p.id != id).toList();
        emit(ProductActionSuccess(updatedList, "Product deleted successfully"));
      },
    );
}

List<ProductModel> _getCurrentProducts() {
if (state is ProductsLoaded) return (state as ProductsLoaded).products;
if (state is ProductActionLoading) return (state as ProductActionLoading).products;
if (state is ProductActionSuccess) return (state as ProductActionSuccess).products;
if (state is ProductActionError) return (state as ProductActionError).products;
return [];
}
}import 'package:equatable/equatable.dart';
import '../../../data/models/pos_models.dart';

abstract class ProductsState extends Equatable {
const ProductsState();

@override
List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {}

class ProductsLoading extends ProductsState {}

class ProductsLoaded extends ProductsState {
final List<ProductModel> products;
const ProductsLoaded(this.products);

@override
List<Object?> get props => [products];
}

class ProductActionLoading extends ProductsState {
final List<ProductModel> products;
const ProductActionLoading(this.products);

@override
List<Object?> get props => [products];
}

class ProductActionSuccess extends ProductsState {
final List<ProductModel> products;
final String message;
const ProductActionSuccess(this.products, this.message);

@override
List<Object?> get props => [products, message];
}

class ProductsError extends ProductsState {
final String message;
const ProductsError(this.message);

@override
List<Object?> get props => [message];
}

class ProductActionError extends ProductsState {
final List<ProductModel> products;
final String message;
const ProductActionError(this.products, this.message);

@override
List<Object?> get props => [products, message];
}import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../../features/data/models/pos_models.dart';
import '../../../../../features/domain/use_cases/main_screen_data_use_case.dart';
import '../../../../error/error_messages.dart';
import '../../../../error/failures.dart';
import '../../../../utils/app_strings.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../../data/models/request/place_order_request.dart';
import '../../../domain/repositories/repository.dart';
import '../../../domain/use_cases/categories_use_case.dart';
import '../../../domain/use_cases/submit_kot_use_case.dart';
import 'order_entry_state.dart';

class OrderEntryCubit extends Cubit<OrderEntryState> {
final MainScreenDataUseCase mainScreenDataUseCase;
final SubmitKitchenOrderUseCase submitKitchenOrderUseCase;
final CategoriesUseCase categoriesUseCase;
final Repository repository;
final LocalDataSource localDataSource;

List<ProductModel> _allProducts = [];
List<ModifierModel> _allModifiers = [];
List<CategoryModel> _categories = [];
CategoryModel? _selectedCategory;
static const branchName = 'pref_01';

OrderEntryCubit({
required this.repository,
required this.localDataSource,
required this.mainScreenDataUseCase,
required this.submitKitchenOrderUseCase,
required this.categoriesUseCase,
}) : super(OrderEntryInitial());


void searchProduct(String query) {
if (state is OrderEntryLoaded) {
final currentState = state as OrderEntryLoaded;

      final filteredList = _allProducts.where((p) =>
          p.name.toLowerCase().contains(query.toLowerCase())
      ).toList();

      emit(currentState.copyWith(currentProducts: filteredList));
    }
}


Future<void> loadInitialData() async {
emit(OrderEntryLoading());
final result = await mainScreenDataUseCase();

    result.fold(
      (failure) {

        if (failure is ConnectionFailure){
          emit(
            OrderEntryError(
              message: ErrorMessages().mapFailureToMessage(failure) ?? "",
            ),
          );
        }
        else if (failure is AuthorizedFailure) {
          emit(OrderEntryError(message: AppStrings.unAuthorizedDes));
        }
        else if (failure is ServerFailure) {
          emit(
            OrderEntryError(
              message:
                  failure.errorResponse.errorDescription ??
                  AppStrings.somethingWentWrong,
            ),
          );
        }
        else {
          emit(OrderEntryError(message: AppStrings.somethingWentWrong));
        }
      },
      (data) async {
        _allProducts = data.products;
        _allModifiers = data.modifiers;
        
        List<CategoryModel> categoriesToUse = data.categories;
        
        final localCategoriesResult = await categoriesUseCase.getAll();
        localCategoriesResult.fold(
          (failure) {
          },
          (localCategories) {
            if (localCategories.isNotEmpty) {
              categoriesToUse = localCategories;
            }
          },
        );
        
        _categories = categoriesToUse;

        if (categoriesToUse.isEmpty) {
          return;
        }

        final initialCategory = categoriesToUse.first;
        _selectedCategory = initialCategory;
        final initialProducts = _getProductForCategory(initialCategory.id);

        emit(
          OrderEntryLoaded(
            categories: categoriesToUse,
            currentProducts: initialProducts,
            selectedCategory: initialCategory,
            cartItems: const [],
          ),
        );
      },
    );
}

List<ModifierModel> get availableModifiers => _allModifiers;

Future<void> refreshCategories() async {
if (state is! OrderEntryLoaded) return;
final currentState = state as OrderEntryLoaded;

     try {
       final localCategoriesResult = await categoriesUseCase.getAll();
       localCategoriesResult.fold(
         (failure) {
         },
         (localCategories) {
           if (localCategories.isNotEmpty) {
             _categories = localCategories;
             
             CategoryModel selectedCat = currentState.selectedCategory;
             if (!_categories.any((c) => c.id == selectedCat.id)) {
               selectedCat = _categories.first;
               _selectedCategory = selectedCat;
             }
             
             final updatedProducts = _getProductForCategory(selectedCat.id);
             
             emit(
               currentState.copyWith(
                 categories: _categories,
                 selectedCategory: selectedCat,
                 currentProducts: updatedProducts,
               ),
             );
           }
         },
       );
     } catch (e) {
     }
    }

void selectCategory(CategoryModel category) {
if (state is OrderEntryLoaded) {
final currentState = state as OrderEntryLoaded;
_selectedCategory = category;

      emit(
        currentState.copyWith(
          selectedCategory: category,
          currentProducts: _getProductForCategory(category.id),
        ),
      );
    }
}

List<ProductModel> _getProductForCategory(int categoryId) {
return _allProducts.where((p) => p.categoryId == categoryId).toList();
}

void resetAfterSubmission() {
if (_categories.isEmpty || _selectedCategory == null) {
loadInitialData();
return;
}

    emit(
      OrderEntryLoaded(
        categories: _categories,
        selectedCategory: _selectedCategory!,
        currentProducts: _getProductForCategory(_selectedCategory!.id),
        cartItems: const [],
      ),
    );
}

void addToCart(ProductModel product) {
if (state is OrderEntryLoaded) {
final currentState = state as OrderEntryLoaded;

      final newItem = CartItem(
        uuid: const Uuid().v4(),
        product: product,
        quantity: 1,
      );

      final updatedCart = List<CartItem>.from(currentState.cartItems)
        ..add(newItem);
      emit(currentState.copyWith(cartItems: updatedCart));
    }
}

void updateQuantity(String itemUuid, int change) {
if (state is OrderEntryLoaded) {
final currentState = state as OrderEntryLoaded;

      final updatedCart =
          currentState.cartItems.map((item) {
            if (item.uuid == itemUuid) {
              final newQty = item.quantity + change;
              return newQty > 0 ? item.copyWith(quantity: newQty) : item;
            }
            return item;
          }).toList();

      emit(currentState.copyWith(cartItems: updatedCart));
    }
}

void updateCartItemDetails(
String uuid,
List<ModifierModel> newModifiers,
String newNote,
) {
if (state is OrderEntryLoaded) {
final currentState = state as OrderEntryLoaded;

      final updatedCart =
          currentState.cartItems.map((item) {
            if (item.uuid == uuid) {
              return item.copyWith(modifiers: newModifiers, note: newNote);
            }
            return item;
          }).toList();

      emit(currentState.copyWith(cartItems: updatedCart));
    }
}

void clearCart() {
if (state is OrderEntryLoaded) {
emit((state as OrderEntryLoaded).copyWith(cartItems: []));
}
}

void removeItem(String uuid) {
if (state is OrderEntryLoaded) {
final currentState = state as OrderEntryLoaded;

      final updatedCart =
          currentState.cartItems.where((item) => item.uuid != uuid).toList();

      emit(currentState.copyWith(cartItems: updatedCart));
    }
}

Future<void> submitOrder({
required String customerId,
required String customerName,
required int orderType,
}) async {
if (state is! OrderEntryLoaded) return;
final currentState = state as OrderEntryLoaded;

    if (currentState.cartItems.isEmpty) return;

    emit(OrderEntryLoading());

    try {
      double subTotal = 0;
      int totalItemsQty = 0;

      for (var item in currentState.cartItems) {
        double itemTotal = item.product.price * item.quantity;
        for (var mod in item.modifiers) {
          itemTotal += (mod.price * item.quantity);
        }
              subTotal += itemTotal;
        totalItemsQty += item.quantity;
      }

      final now = DateTime.now();
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final timeFormatter = DateFormat('h:mm:ss a');
      final dateTimeFormatter = DateFormat('yyyy-MM-dd h:mm:ss a');

      List<OrderItemRequest> orderItems =
          currentState.cartItems.expand((cartItem) {
            return List.generate(cartItem.quantity, (index) {
              String modIdsStr = "";
              String modPricesStr = "";
              ModifiersJsonData? modJsonData;

              if (cartItem.modifiers.isNotEmpty) {
                modIdsStr = cartItem.modifiers.map((m) => m.id).join(',');
                modPricesStr = cartItem.modifiers
                    .map((m) => m.price.toStringAsFixed(2))
                    .join(',');

                final Map<int, List<ModifierModel>> groupedMods = {};
                for (var mod in cartItem.modifiers) {
                  if (!groupedMods.containsKey(mod.id)) {
                    groupedMods[mod.id] = [];
                  }
                  groupedMods[mod.id]!.add(mod);
                }

                List<ModifierItem> modItems =
                    groupedMods.entries.map((entry) {
                      final mod = entry.value.first;

                      final int totalQtyForLine = entry.value.length;
                      final double totalPrice = mod.price * totalQtyForLine;

                      return ModifierItem(
                        modifierId: mod.id,
                        modifierName: mod.name,
                        modifierPrice: mod.price,
                        totalQty: totalQtyForLine,
                        totalPrice: totalPrice,
                        units: [
                          ModifierUnit(
                            unit: 1,
                            qty: totalQtyForLine,
                            linePrice: totalPrice,
                          ),
                        ],
                      );
                    }).toList();

                modJsonData = ModifiersJsonData(
                  itemNote: cartItem.note,
                  modifiers: modItems,
                );
              } else if (cartItem.note.isNotEmpty) {
                modJsonData = ModifiersJsonData(
                  itemNote: cartItem.note,
                  modifiers: [],
                );
              }

              return OrderItemRequest(
                foodMenuId: cartItem.product.id,
                menuName: cartItem.product.name,
                menuUnitPrice: cartItem.product.price,
                qty: 1,
                modifiersId: modIdsStr,
                modifiersName: "",
                modifiersPrice: modPricesStr,
                modifiersJson: modJsonData,
              );
            });
          }).toList();

      final request = PlaceOrderRequest(
        saleNo: _generateSaleNo(),
        randomCode: _generateRandomCode(),
        customerId: customerId,
        customerName: customerName,
        status: "Pending",

        totalItemsInCart: orderItems.length,
        totalItemsInCartQty: totalItemsQty,

        subTotal: subTotal,
        totalPayable: subTotal,
        saleDate: dateFormatter.format(now),
        dateTime: dateTimeFormatter.format(now),
        orderTime: timeFormatter.format(now),
        orderType: orderType,
        items: orderItems,
      );

      final result = await submitKitchenOrderUseCase(request);

      result.fold(
        (failure) {
          String errorMsg = AppStrings.somethingWentWrong;
          if (failure is ServerFailure) {
            errorMsg = failure.errorResponse.errorDescription ?? errorMsg;
          }
          emit(OrderEntryError(message: errorMsg));
        },
        (response) {
          emit(OrderSubmissionSuccess(response: response));
        },
      );
    } catch (e) {
      emit(OrderEntryError(message: "Error preparing order: $e"));
    }
}

String _generateSaleNo() {
final dateStr = DateFormat('yyMMdd').format(DateTime.now());
final random = Random().nextInt(9999);
return "POS-$dateStr-$random";
}

String _generateRandomCode() {
final random = Random().nextInt(999999);
return "RND-${DateFormat('yyMMdd').format(DateTime.now())}-$random";
}

Future<void> refreshAllLocalData() async {
final localCatsResult = await categoriesUseCase.getAll();

    final localProdsResult = await repository.getLocalProducts();

    localCatsResult.fold((f) => null, (localCats) {
      localProdsResult.fold((f) => null, (localProds) {
        _categories = localCats;
        _allProducts = localProds;

        if (state is OrderEntryLoaded) {
          final currentState = state as OrderEntryLoaded;

          CategoryModel selectedCat = currentState.selectedCategory;
          if (!_categories.any((c) => c.id == selectedCat.id)) {
            selectedCat = _categories.isNotEmpty ? _categories.first : selectedCat;
          }

          emit(currentState.copyWith(
            categories: _categories,
            selectedCategory: selectedCat,
            currentProducts: _getProductForCategory(selectedCat.id),
          ));
        }
      });
    });
}

Future<String> getBranch() => localDataSource.getBranch();
}
import 'package:equatable/equatable.dart';

import '../../../data/models/pos_models.dart';
import '../../../data/models/response/place_order_response.dart';

abstract class OrderEntryState extends Equatable {
const OrderEntryState();

@override
List<Object> get props => [];
}

class OrderEntryInitial extends OrderEntryState {}

class OrderEntryLoading extends OrderEntryState {}

class OrderEntryLoaded extends OrderEntryState {
final List<CategoryModel> categories;
final List<ProductModel> currentProducts;
final CategoryModel selectedCategory;
final List<CartItem> cartItems;

const OrderEntryLoaded({
required this.categories,
required this.currentProducts,
required this.selectedCategory,
required this.cartItems,
});

double get grandTotal => cartItems.fold(0, (sum, item) => sum + item.total);

OrderEntryLoaded copyWith({
List<CategoryModel>? categories,
List<ProductModel>? currentProducts,
CategoryModel? selectedCategory,
List<CartItem>? cartItems,
}) {
return OrderEntryLoaded(
categories: categories ?? this.categories,
currentProducts: currentProducts ?? this.currentProducts,
selectedCategory: selectedCategory ?? this.selectedCategory,
cartItems: cartItems ?? this.cartItems,
);
}

@override
List<Object> get props => [
categories,
currentProducts,
selectedCategory,
cartItems,
];
}

class OrderEntryError extends OrderEntryState {
final String message;

const OrderEntryError({required this.message});
}

class OrderSubmissionSuccess extends OrderEntryState {
final KitchenOrderResponse response;

const OrderSubmissionSuccess({required this.response});
}
import 'package:d_pos/features/presentation/cubit/running_orders/running_orders_state.dart';
import 'package:d_pos/utils/app_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../error/failures.dart';
import '../../../../utils/app_strings.dart';
import '../../../domain/use_cases/get_running_orders_use_case.dart';
import '../../../domain/use_cases/print_running_order_use_case.dart';

class RunningOrdersCubit extends Cubit<RunningOrdersState> {
final GetRunningOrdersUseCase getRunningOrdersUseCase;
final PrintRunningOrderUseCase printRunningOrderUseCase;

RunningOrdersCubit({
required this.getRunningOrdersUseCase,
required this.printRunningOrderUseCase,
}) : super(RunningOrdersInitial());

Future<void> fetchRunningOrders({bool isBackgroundRefresh = false}) async {
if (!isBackgroundRefresh) {
emit(RunningOrdersLoading());
}

    final result = await getRunningOrdersUseCase(
      AppConstants.userId!,
    );

    result.fold(
      (failure) {
        String msg = AppStrings.somethingWentWrong;
        if (failure is ServerFailure) {
          msg = failure.errorResponse.errorDescription ?? msg;
        }
        emit(RunningOrdersError(message: msg));
      },
      (baseResponse) {
        final orders = baseResponse.data?.runningOrders ?? [];
        orders.sort((a, b) => b.id.compareTo(a.id));
        emit(RunningOrdersLoaded(orders: orders));
      },
    );
}

Future<void> printOrder(
int orderId, {
required Function(String) onSuccess,
required Function(String) onError,
}) async {
final result = await printRunningOrderUseCase(orderId);

    result.fold(
      (failure) {
        String msg = "Print Failed";
        if (failure is ServerFailure) {
          msg = failure.errorResponse.errorDescription ?? msg;
        }
        onError(msg);
      },
      (response) {
        onSuccess(response.message);
      },
    );
}
}
import '../../../data/models/response/running_orders_response_model.dart';

abstract class RunningOrdersState {}

class RunningOrdersInitial extends RunningOrdersState {}

class RunningOrdersLoading extends RunningOrdersState {}

class RunningOrdersLoaded extends RunningOrdersState {
final List<RunningOrderModel> orders;

RunningOrdersLoaded({required this.orders});
}

class RunningOrdersError extends RunningOrdersState {
final String message;

RunningOrdersError({required this.message});
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/navigation_routes.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../cubit/login/login_cubit.dart';
import '../../cubit/login/login_state.dart';

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
with SingleTickerProviderStateMixin {
final TextEditingController _userController = TextEditingController();
final TextEditingController _passController = TextEditingController();
final FocusNode _userFocus = FocusNode();
final FocusNode _passFocus = FocusNode();
bool _obscurePass = true;
bool _rememberMe = false;
late String branchName = "";
final LocalDataSource _localDataSource = sl<LocalDataSource>();
static const _keyEmail = 'remembered_email';
static const _keyPass = 'remembered_pass';
static const _keyRemember = 'remember_me';

late final AnimationController _animController;
late final Animation<double> _fadeAnim;
late final Animation<Offset> _slideAnim;

@override
void initState() {
super.initState();
_animController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 700),
);
_fadeAnim = CurvedAnimation(
parent: _animController,
curve: Curves.easeOut,
);
_slideAnim = Tween<Offset>(
begin: const Offset(0, 0.12),
end: Offset.zero,
).animate(
CurvedAnimation(parent: _animController, curve: Curves.easeOut),
);
_animController.forward();
_loadRememberedCredentials();
getBranchName();
}

Future<void> _loadRememberedCredentials() async {
final prefs = await SharedPreferences.getInstance();
final remembered = prefs.getBool(_keyRemember) ?? false;
if (remembered) {
setState(() {
_rememberMe = true;
_userController.text = prefs.getString(_keyEmail) ?? '';
_passController.text = prefs.getString(_keyPass) ?? '';
});
}
}

Future<void> _saveOrClearCredentials() async {
final prefs = await SharedPreferences.getInstance();
if (_rememberMe) {
await prefs.setBool(_keyRemember, true);
await prefs.setString(_keyEmail, _userController.text.trim());
await prefs.setString(_keyPass, _passController.text);
} else {
await prefs.remove(_keyRemember);
await prefs.remove(_keyEmail);
await prefs.remove(_keyPass);
}
}

/// Persists the token so the user stays logged in across app restarts.
Future<void> _persistToken(String token) async {
final prefs = await SharedPreferences.getInstance();
await prefs.setString('auth_token', token);
}

@override
void dispose() {
_animController.dispose();
_userController.dispose();
_passController.dispose();
_userFocus.dispose();
_passFocus.dispose();
super.dispose();
}

Future<void> getBranchName() async {
branchName = await _localDataSource.getBranch();
if (mounted) setState(() {});
}


@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: AppTheme.bgBase,
body: BlocConsumer<LoginCubit, LoginState>(
listener: (context, state) async {
if (state is LoginFailure) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Row(
children: [
const Icon(Icons.error_outline,
color: Colors.white, size: 18),
const SizedBox(width: 8),
Expanded(child: Text(state.message)),
],
),
backgroundColor: AppTheme.red,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12)),
margin: const EdgeInsets.all(16),
),
);
}
if (state is LoginSuccess) {
// Persist the token so the user stays logged in across restarts
await _persistToken(state.token);
if (context.mounted) {
Navigator.pushReplacementNamed(context, Routes.kMainPosScreen);
}
}
},
builder: (context, state) {
final isLoading = state is LoginLoading || state is LoginSyncing;

          return Stack(
            children: [
              // Ambient background glow
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.gold.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.green.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.goldGradient,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.gold
                                            .withValues(alpha: 0.35),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_menu_rounded,
                                    color: AppTheme.textOnGold,
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Text(
                                'Sample Restaurant',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${branchName.isNotEmpty ? branchName : ''} · POS System',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(height: 48),

                              // Card container
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.bgBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Enter your credentials to continue',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Email field
                                    _buildLabel('Email Address'),
                                    const SizedBox(height: 8),
                                    _buildTextField(
                                      controller: _userController,
                                      focusNode: _userFocus,
                                      hint: 'name@restaurant.com',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.email_outlined,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _passFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: 20),

                                    // Password field
                                    _buildLabel('Password'),
                                    const SizedBox(height: 8),
                                    _buildTextField(
                                      controller: _passController,
                                      focusNode: _passFocus,
                                      hint: '••••••••',
                                      obscure: _obscurePass,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      textInputAction: TextInputAction.done,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePass
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: AppTheme.textHint,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                                () => _obscurePass = !_obscurePass),
                                      ),
                                      onSubmitted: (_) =>
                                          _handleLogin(context),
                                    ),

                                    const SizedBox(height: 16),

                                    // Remember Me
                                    GestureDetector(
                                      onTap: () => setState(
                                              () => _rememberMe = !_rememberMe),
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              onChanged: (val) => setState(
                                                      () => _rememberMe =
                                                      val ?? false),
                                              activeColor: AppTheme.gold,
                                              checkColor: AppTheme.textOnGold,
                                              side: const BorderSide(
                                                  color: AppTheme.textHint,
                                                  width: 1.5),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(4),
                                              ),
                                              materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'Remember me',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 28),

                                    // Sign in button
                                    AnimatedContainer(
                                      duration:
                                      const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        gradient: isLoading
                                            ? null
                                            : AppTheme.goldGradient,
                                        color: isLoading
                                            ? AppTheme.bgCardElevated
                                            : null,
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        boxShadow: isLoading
                                            ? []
                                            : [
                                          BoxShadow(
                                            color: AppTheme.gold
                                                .withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset:
                                            const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => _handleLogin(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          disabledBackgroundColor:
                                          Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child:
                                          CircularProgressIndicator(
                                            color: AppTheme.gold,
                                            strokeWidth: 2,
                                          ),
                                        )
                                            : const Text(
                                          'SIGN IN',
                                          style: TextStyle(
                                            color: AppTheme.textOnGold,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
}

Widget _buildLabel(String text) {
return Text(
text,
style: const TextStyle(
color: AppTheme.textSecondary,
fontSize: 13,
fontWeight: FontWeight.w500,
),
);
}

Widget _buildTextField({
required TextEditingController controller,
required FocusNode focusNode,
required String hint,
required IconData prefixIcon,
TextInputType? keyboardType,
bool obscure = false,
TextInputAction? textInputAction,
Widget? suffixIcon,
ValueChanged<String>? onSubmitted,
}) {
return TextField(
controller: controller,
focusNode: focusNode,
obscureText: obscure,
keyboardType: keyboardType,
textInputAction: textInputAction,
style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
onSubmitted: onSubmitted,
decoration: InputDecoration(
hintText: hint,
hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
filled: true,
fillColor: AppTheme.bgCardElevated,
prefixIcon: Icon(prefixIcon, color: AppTheme.textHint, size: 20),
suffixIcon: suffixIcon,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(vertical: 16),
),
);
}

void _handleLogin(BuildContext context) {
FocusScope.of(context).unfocus();
_saveOrClearCredentials();
context.read<LoginCubit>().login(
_userController.text.trim(),
_passController.text,
);
}
}import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../../core/service/dependency_injection.dart';
import '../../../../data/data_sources/local_data_sources.dart';


class VideoCarouselTab extends StatefulWidget {
const VideoCarouselTab({super.key});

@override
State<VideoCarouselTab> createState() => _VideoCarouselTabState();
}

class _VideoCarouselTabState extends State<VideoCarouselTab> {
List<String> _videoPaths = [];
List<String> _imagePaths = [];
final _localDataSource = sl<LocalDataSource>();
late PageController _videoPageController;
late PageController _imagePageController;

int _currentVideoIndex = 0;
int _currentImageIndex = 0;
bool _isAutoAdvancing = false;
static const int _kVirtualPageOffset = 10000;

@override
void initState() {
super.initState();
_videoPageController = PageController(
initialPage: _kVirtualPageOffset,
);
_imagePageController = PageController(viewportFraction: 0.88);
_loadMedia();
}

Future<void> _loadMedia() async {
final videos = await _localDataSource.getVideoPaths();
final images = await _localDataSource.getImagePaths();
if (mounted) {
setState(() {
_videoPaths = videos;
_imagePaths = images;
if (_currentVideoIndex >= _videoPaths.length) _currentVideoIndex = 0;
if (_currentImageIndex >= _imagePaths.length) _currentImageIndex = 0;
});
}
}

Future<void> reload() => _loadMedia();

void _onVideoFinished() {
if (_isAutoAdvancing || !mounted || _videoPaths.isEmpty) return;
_isAutoAdvancing = true;

    final currentPage = _videoPageController.page?.toInt() ?? _kVirtualPageOffset;
    final nextPage = currentPage + 1;
    
    _videoPageController
        .animateToPage(nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut)
        .then((_) => _isAutoAdvancing = false);
}

@override
void dispose() {
_videoPageController.dispose();
_imagePageController.dispose();
super.dispose();
}


@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF0E0F1C),
body: Column(
children: [
AspectRatio(
aspectRatio: 16 / 9,
child: _videoPaths.isEmpty
? _buildEmptyVideo()
: _buildVideoPageView(),
),

          if (_videoPaths.length > 1) _buildVideoDots(),

          _buildGalleryLabel(),

          Expanded(
            child: _imagePaths.isEmpty
                ? _buildEmptyImages()
                : _buildImagePageView(),
          ),

          if (_imagePaths.length > 1) _buildImageDots(),

          const SizedBox(height: 10),
        ],
      ),
    );
}


Widget _buildVideoPageView() {
if (_videoPaths.isEmpty) return const SizedBox();

    return PageView.builder(
      controller: _videoPageController,
      itemCount: 100000, 
      onPageChanged: (i) => setState(() => _currentVideoIndex = i % _videoPaths.length),
      itemBuilder: (context, virtualIndex) {
        final actualIndex = virtualIndex % _videoPaths.length;
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: _VideoPlayerCard(
              key: ValueKey('${_videoPaths[actualIndex]}_$virtualIndex'),
              file: File(_videoPaths[actualIndex]),
              isActive: actualIndex == _currentVideoIndex,
              onFinished: _onVideoFinished,
            ),
          ),
        );
      },
    );
}


Widget _buildImagePageView() {
return PageView.builder(
controller: _imagePageController,
itemCount: _imagePaths.length,
onPageChanged: (i) => setState(() => _currentImageIndex = i),
itemBuilder: (context, index) {
final isActive = index == _currentImageIndex;
return AnimatedScale(
scale: isActive ? 1.0 : 0.93,
duration: const Duration(milliseconds: 300),
curve: Curves.easeOut,
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
child: GestureDetector(
onTap: () => _showImagePopup(context, index),
child: ClipRRect(
borderRadius: BorderRadius.circular(16),
child: Image.file(
File(_imagePaths[index]),
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) => Container(
color: const Color(0xFF141628),
child: const Icon(Icons.broken_image_outlined,
color: Color(0xFF4A4D6A), size: 40),
),
),
),
),
),
);
},
);
}


void _showImagePopup(BuildContext context, int index) {
showGeneralDialog(
context: context,
barrierDismissible: true,
barrierLabel: 'dismiss',
barrierColor: Colors.transparent,
transitionDuration: const Duration(milliseconds: 300),
pageBuilder: (_, __, ___) => const SizedBox.shrink(),
transitionBuilder: (ctx, animation, _, __) {
final curved = CurvedAnimation(
parent: animation,
curve: Curves.easeOutCubic,
);
return FadeTransition(
opacity: curved,
child: _ImagePopup(
paths: _imagePaths,
initialIndex: index,
scaleAnimation: curved,
),
);
},
);
}


Widget _buildVideoDots() {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 6),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: List.generate(_videoPaths.length, (i) {
final active = i == _currentVideoIndex;
return GestureDetector(
onTap: () {
final currentPage = _videoPageController.page?.toInt() ?? _kVirtualPageOffset;
final currentModulo = currentPage % _videoPaths.length;

              int targetPage = currentPage + (i - currentModulo);
              if (targetPage < 0) targetPage += _videoPaths.length;
              
              _videoPageController.animateToPage(targetPage,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: active
                    ? const LinearGradient(
                    colors: [Color(0xFFC8973A), Color(0xFFE8C870)])
                    : null,
                color: active ? null : const Color(0xFF2A2D48),
              ),
            ),
          );
        }),
      ),
    );
}


Widget _buildImageDots() {
return Padding(
padding: const EdgeInsets.only(top: 6),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: List.generate(_imagePaths.length, (i) {
final active = i == _currentImageIndex;
return AnimatedContainer(
duration: const Duration(milliseconds: 280),
margin: const EdgeInsets.symmetric(horizontal: 3),
width: active ? 14 : 5,
height: 5,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(3),
color: active
? const Color(0xFFC8973A)
: const Color(0xFF2A2D48),
),
);
}),
),
);
}


Widget _buildGalleryLabel() {
return Padding(
padding: const EdgeInsets.fromLTRB(18, 4, 18, 2),
child: Row(
children: [
const Text(
'GALLERY',
style: TextStyle(
color: Color(0xFF5A5D7A),
fontSize: 10,
fontWeight: FontWeight.w700,
letterSpacing: 1.6,
),
),
const SizedBox(width: 10),
Expanded(
child: Container(height: 1, color: const Color(0xFF1A1C30))),
const SizedBox(width: 10),
Text(
'${_imagePaths.length}',
style: const TextStyle(
color: Color(0xFF3A3D58),
fontSize: 10,
fontWeight: FontWeight.w600,
),
),
],
),
);
}


Widget _buildEmptyVideo() {
return Padding(
padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
child: Container(
decoration: BoxDecoration(
color: const Color(0xFF141628),
borderRadius: BorderRadius.circular(22),
border: Border.all(color: const Color(0xFF1E2035)),
),
child: const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.video_library_outlined,
size: 52, color: Color(0xFF2A2D48)),
SizedBox(height: 12),
Text('No videos added',
style:
TextStyle(color: Color(0xFF4A4D6A), fontSize: 14)),
SizedBox(height: 4),
Text('Add videos from the menu',
style:
TextStyle(color: Color(0xFF2E3050), fontSize: 11)),
],
),
),
),
);
}

Widget _buildEmptyImages() {
return const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.photo_library_outlined,
size: 36, color: Color(0xFF2A2D48)),
SizedBox(height: 8),
Text('No images added',
style: TextStyle(color: Color(0xFF4A4D6A), fontSize: 12)),
],
),
);
}
}


class _ImagePopup extends StatefulWidget {
final List<String> paths;
final int initialIndex;
final Animation<double> scaleAnimation;

const _ImagePopup({
required this.paths,
required this.initialIndex,
required this.scaleAnimation,
});

@override
State<_ImagePopup> createState() => _ImagePopupState();
}

class _ImagePopupState extends State<_ImagePopup> {
late PageController _ctrl;
late int _index;

@override
void initState() {
super.initState();
_index = widget.initialIndex;
_ctrl = PageController(initialPage: _index);
}

@override
void dispose() {
_ctrl.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: () => Navigator.of(context).pop(),
behavior: HitTestBehavior.opaque,
child: Stack(
fit: StackFit.expand,
children: [
BackdropFilter(
filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
child: Container(
color: Colors.black.withValues(alpha: 0.55),
),
),

          ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
              CurvedAnimation(
                parent: widget.scaleAnimation,
                curve: Curves.easeOutBack,
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: () {}, 
                      child: PageView.builder(
                        controller: _ctrl,
                        itemCount: widget.paths.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  File(widget.paths[index]),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    color: Color(0xFF4A4D6A),
                                    size: 64,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (widget.paths.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.paths.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 16 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: active
                                ? const Color(0xFFC8973A)
                                : Colors.white24,
                          ),
                        );
                      }),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
}
}


class _VideoPlayerCard extends StatefulWidget {
final File file;
final bool isActive;
final VoidCallback onFinished;

const _VideoPlayerCard({
super.key,
required this.file,
required this.isActive,
required this.onFinished,
});

@override
State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
VideoPlayerController? _controller;
bool _initialized = false;
bool _showControls = false;
bool _finishedFired = false;
bool _hasError = false;

@override
void initState() {
super.initState();
_initController();
}

Future<void> _initController() async {
try {
final ctrl = VideoPlayerController.file(widget.file);
_controller = ctrl;
await ctrl.initialize();
ctrl.setLooping(false);
ctrl.addListener(_onVideoEvent);
if (!mounted) {
ctrl.dispose();
return;
}
setState(() => _initialized = true);
if (widget.isActive) ctrl.play();
} catch (_) {
if (mounted) setState(() => _hasError = true);
}
}

void _onVideoEvent() {
if (!mounted || _controller == null) return;
final pos = _controller!.value.position;
final dur = _controller!.value.duration;
if (!_finishedFired &&
dur.inMilliseconds > 0 &&
pos.inMilliseconds >= dur.inMilliseconds - 200) {
_finishedFired = true;
widget.onFinished();
}
if (mounted) setState(() {});
}

@override
void didUpdateWidget(_VideoPlayerCard old) {
super.didUpdateWidget(old);
if (_controller == null || !_initialized) return;
if (widget.isActive && !old.isActive) {
_finishedFired = false;
_controller!.seekTo(Duration.zero);
_controller!.play();
} else if (!widget.isActive && old.isActive) {
_controller!.pause();
}
}

@override
void dispose() {
_controller?.removeListener(_onVideoEvent);
_controller?.dispose();
super.dispose();
}

void _togglePlay() {
if (_controller == null || !_initialized) return;
_controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
setState(() => _showControls = !_showControls);
}

String _fmt(Duration d) {
final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
return '$m:$s';
}

@override
Widget build(BuildContext context) {
return ColoredBox(
color: Colors.black,
child: _hasError
? const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.error_outline,
color: Color(0xFFC8973A), size: 40),
SizedBox(height: 8),
Text('Unable to load video',
style:
TextStyle(color: Colors.white54, fontSize: 13)),
],
),
)
: !_initialized
? const Center(
child: CircularProgressIndicator(
color: Color(0xFFC8973A), strokeWidth: 2),
)
: GestureDetector(
onTap: _togglePlay,
child: Stack(
fit: StackFit.expand,
children: [
FittedBox(
fit: BoxFit.cover,
clipBehavior: Clip.hardEdge,
child: SizedBox(
width: _controller!.value.size.width,
height: _controller!.value.size.height,
child: VideoPlayer(_controller!),
),
),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),

            Center(
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                        Colors.white.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildProgressBar(),
            ),
          ],
        ),
      ),
    );
}

Widget _buildProgressBar() {
return Padding(
padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
child: ValueListenableBuilder<VideoPlayerValue>(
valueListenable: _controller!,
builder: (_, value, __) {
final total = value.duration.inMilliseconds.toDouble();
final current = value.position.inMilliseconds.toDouble();
final progress =
total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(value.position),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  Text(_fmt(value.duration),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) {
                  final box =
                  context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final x =
                  d.localPosition.dx.clamp(0.0, box.size.width);
                  _controller!
                      .seekTo(value.duration * (x / box.size.width));
                },
                child: SizedBox(
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFC8973A),
                                  Color(0xFFFFE4A0),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment:
                        Alignment((progress * 2.0) - 1.0, 0.0),
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8C870),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
}
}import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/app_theme.dart';

class DrawerItem extends StatelessWidget {
final IconData icon;
final String label;
final VoidCallback onTap;
final Color iconColor;
final Color labelColor;

const DrawerItem({super.key,
required this.icon,
required this.label,
required this.onTap,
this.iconColor = AppTheme.textSecondary,
this.labelColor = AppTheme.textPrimary,
});

@override
Widget build(BuildContext context) {
return ListTile(
onTap: onTap,
leading: Icon(icon, color: iconColor, size: 22),
title: Text(
label,
style: TextStyle(
color: labelColor,
fontSize: 14,
fontWeight: FontWeight.w500,
),
),
horizontalTitleGap: 8,
contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
);
}
}
import 'dart:convert';
import 'dart:io'; // Required for File checking

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/service/global_image_settings.dart';
import '../../../../../utils/app_theme.dart';
import '../../../../data/models/pos_models.dart';

class ProductListItem extends StatelessWidget {
final ProductModel product;
final bool isInCart;
final String imageUrl;
final VoidCallback onAdd;

const ProductListItem({
super.key,
required this.product,
required this.isInCart,
required this.imageUrl,
required this.onAdd,
});

@override
Widget build(BuildContext context) {
final imgWidth = 100.w;
final imgHeight = 60.h;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isInCart
              ? AppTheme.gold.withValues(alpha: 0.4)
              : AppTheme.bgBorder,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: _buildProductImage(imgWidth, imgHeight),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                if(product.alternativeName != null && product.alternativeName!.isNotEmpty)Text(
                  product.alternativeName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if(product.alternativeName != null && product.alternativeName!.isNotEmpty)SizedBox(height: 4.h),
                Text(
                  'QR ${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onAdd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: isInCart ? null : AppTheme.goldGradient,
                color: isInCart ? AppTheme.green.withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(10.r),
                border: isInCart
                    ? Border.all(color: AppTheme.green.withValues(alpha: 0.4))
                    : null,
              ),
              child: isInCart
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: AppTheme.green, size: 16.sp),
                  SizedBox(width: 4.w),
                  Text(
                    'Added',
                    style: TextStyle(
                      color: AppTheme.green,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : Text(
                'Add',
                style: TextStyle(
                  color: AppTheme.textOnGold,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
}

// --- SMART IMAGE LOADER ---
Widget _buildProductImage(double width, double height) {

    final String? localPath = product.localPath;
    // final bool shouldShowLocal = product.showLocalImage;
    final bool shouldShowLocal = GlobalImageSettings().showLocalImages;

    // 1. Try Local File or Base64 (from product.localPath) - ONLY if showLocalImage is true
    if (shouldShowLocal && localPath != null && localPath.isNotEmpty) {
      // Robust Check: Is it a File Path?
      if (localPath.startsWith('/') && localPath.length < 500) {
        final file = File(localPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildNetworkFallback(width, height),
          );
        }
      }
      // It's a Base64 string
      else {
        try {
          return Image.memory(
            base64Decode(localPath.trim().split(',').last),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildNetworkFallback(width, height),
          );
        } catch (e) {
          debugPrint("Base64 Decode Error in Product Item: $e");
        }
      }
    }

    // 2. Network Fallback
    return _buildNetworkFallback(width, height);
}

Widget _buildNetworkFallback(double width, double height) {
// Attempt specific product URL if provided
if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
return Image.network(
product.imageUrl!,
width: width,
height: height,
fit: BoxFit.cover,
errorBuilder: (_, __, ___) => _buildPlaceholder(width, height),
);
}

    // Attempt generic fallback URL
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPlaceholder(width, height),
    );
}

Widget _buildPlaceholder(double width, double height) {
return Container(
width: width,
height: height,
color: AppTheme.bgCardElevated,
child: Icon(Icons.fastfood, color: AppTheme.textHint, size: 24.sp),
);
}
}import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QtyBtn extends StatelessWidget {
final IconData icon;
final VoidCallback onTap;
final Color color;

const QtyBtn({required this.icon, required this.onTap, required this.color});

@override
Widget build(BuildContext context) {
return InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(8.r),
child: Container(
padding: EdgeInsets.all(6.r),
child: Icon(icon, color: color, size: 16.sp),
),
);
}
}import 'package:flutter/cupertino.dart';

/// Decorative hollow circle
class Ring extends StatelessWidget {
final double size;
final Color color;
final double opacity;

const Ring({required this.size, required this.color, required this.opacity});

@override
Widget build(BuildContext context) {
return Container(
width: size,
height: size,
decoration: BoxDecoration(
shape: BoxShape.circle,
border: Border.all(color: color.withValues(alpha: opacity), width: 1.5),
),
);
}
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/order_entry/order_entry_cubit.dart';

class EditItemScreen extends StatefulWidget {
final CartItem item;

const EditItemScreen({super.key, required this.item});

@override
State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
late TextEditingController _noteController;
late List<ModifierModel> _selectedModifiers;

@override
void initState() {
super.initState();
_noteController = TextEditingController(text: widget.item.note);
_selectedModifiers = List.from(widget.item.modifiers);
}

@override
void dispose() {
_noteController.dispose();
super.dispose();
}

int _getQty(ModifierModel mod) =>
_selectedModifiers.where((m) => m.id == mod.id).length;

void _addModifier(ModifierModel mod) =>
setState(() => _selectedModifiers.add(mod));

void _removeModifier(ModifierModel mod) => setState(() {
final idx = _selectedModifiers.indexWhere((m) => m.id == mod.id);
if (idx != -1) _selectedModifiers.removeAt(idx);
});

@override
Widget build(BuildContext context) {
final allModifiers = context.read<OrderEntryCubit>().availableModifiers;

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Customize Item',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.bgBorder),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.bgBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.fastfood_rounded,
                              color: AppTheme.textOnGold, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.product.name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'QR ${widget.item.product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppTheme.gold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Note field
                  _SectionHeader(
                    icon: Icons.edit_note_rounded,
                    title: 'Preparation Note',
                    subtitle: 'Optional',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Less spicy, extra sauce, hot...',
                      hintStyle: const TextStyle(
                          color: AppTheme.textHint, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: AppTheme.bgBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: AppTheme.bgBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.gold, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Modifiers
                  _SectionHeader(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Extras & Modifiers',
                    subtitle: '${_selectedModifiers.length} selected',
                  ),
                  const SizedBox(height: 14),

                  if (allModifiers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.bgBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'No modifiers available.',
                          style: TextStyle(color: AppTheme.textHint),
                        ),
                      ),
                    )
                  else
                    ...allModifiers.map((mod) {
                      final qty = _getQty(mod);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: qty > 0
                              ? AppTheme.gold.withValues(alpha: 0.06)
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: qty > 0
                                ? AppTheme.gold.withValues(alpha: 0.35)
                                : AppTheme.bgBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(mod.name,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15)),
                                  Text('+ QR ${mod.price}',
                                      style: const TextStyle(
                                          color: AppTheme.gold,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            // Qty stepper
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.bgCardElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  _StepBtn(
                                    icon: Icons.remove,
                                    color: qty > 0
                                        ? AppTheme.red
                                        : AppTheme.textHint,
                                    onTap: qty > 0
                                        ? () => _removeModifier(mod)
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$qty',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: qty > 0
                                            ? AppTheme.gold
                                            : AppTheme.textHint,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  _StepBtn(
                                    icon: Icons.add,
                                    color: AppTheme.green,
                                    onTap: () => _addModifier(mod),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Confirm button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              border:
              const Border(top: BorderSide(color: AppTheme.bgBorder)),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.read<OrderEntryCubit>().updateCartItemDetails(
                    widget.item.uuid,
                    _selectedModifiers,
                    _noteController.text,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_rounded,
                    color: AppTheme.textOnGold),
                label: const Text(
                  'CONFIRM CHANGES',
                  style: TextStyle(
                    color: AppTheme.textOnGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
}
}

class _SectionHeader extends StatelessWidget {
final IconData icon;
final String title;
final String subtitle;

const _SectionHeader({
required this.icon,
required this.title,
required this.subtitle,
});

@override
Widget build(BuildContext context) {
return Row(
children: [
Icon(icon, color: AppTheme.gold, size: 18),
const SizedBox(width: 8),
Text(title,
style: const TextStyle(
color: AppTheme.textPrimary,
fontSize: 15,
fontWeight: FontWeight.w600)),
const Spacer(),
Text(subtitle,
style: const TextStyle(
color: AppTheme.textSecondary, fontSize: 12)),
],
);
}
}

class _StepBtn extends StatelessWidget {
final IconData icon;
final Color color;
final VoidCallback? onTap;

const _StepBtn({
required this.icon,
required this.color,
this.onTap,
});

@override
Widget build(BuildContext context) {
return InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(8),
child: Padding(
padding: const EdgeInsets.all(8),
child: Icon(icon, color: color, size: 16),
),
);
}
}import 'dart:convert';
import 'dart:io';

import 'package:d_pos/features/presentation/views/main_dashboard/widget/drawer_item.dart';
import 'package:d_pos/features/presentation/views/main_dashboard/widget/product_list_item.dart';
import 'package:d_pos/features/presentation/views/main_dashboard/widget/qty_button.dart';
import 'package:d_pos/features/presentation/views/main_dashboard/widget/ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../../core/service/global_image_settings.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/order_entry/order_entry_cubit.dart';
import '../../cubit/order_entry/order_entry_state.dart';
import '../../widget/product_image_popup.dart';
import '../manage_categories/manage_categories_screen.dart';
import '../manage_featured/manage_images_screen.dart';
import '../manage_featured/manage_videos_screen.dart';
import '../manage_products/manage_products_screen.dart';
import 'edit_item_screen.dart';
import 'featured/video_carousel_tab.dart';
import 'order_summary_screen.dart';

class MainPosScreen extends StatefulWidget {
const MainPosScreen({super.key});

@override
State<MainPosScreen> createState() => _MainPosScreenState();
}

class _MainPosScreenState extends State<MainPosScreen>
with SingleTickerProviderStateMixin {
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
final TextEditingController _searchController = TextEditingController();
late TabController _tabController;
final LocalDataSource _localDataSource = sl<LocalDataSource>();
final _videoCarouselKey = GlobalKey<State>();
late String branchName = "";
static const String _foodImg =
'https://images.unsplash.com/photo-1606787366850-de6330128bfc?q=80&w=300&auto=format&fit=crop';

@override
void initState() {
super.initState();
_tabController = TabController(length: 4, vsync: this);
_tabController.addListener(_onTabChanged);
context.read<OrderEntryCubit>().loadInitialData();
getBranchName();
}

Future<void> getBranchName() async {
branchName = await _localDataSource.getBranch();
if (mounted) setState(() {});
}


void _onTabChanged() {
if (_tabController.index == 3) {
final state = _videoCarouselKey.currentState;
if (state != null) {
// Call reload method dynamically
(state as dynamic).reload();
}
}
}

@override
void dispose() {
_tabController.removeListener(_onTabChanged);
_tabController.dispose();
_searchController.dispose();
super.dispose();
}


PreferredSizeWidget _buildAppBar(OrderEntryState state) {
final cartCount = state is OrderEntryLoaded ? state.cartItems.length : 0;

    return AppBar(
      backgroundColor: AppTheme.bgSurface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppTheme.textOnGold,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sample Restaurant',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (branchName.isNotEmpty)
                Text(
                  branchName,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: AppTheme.bgSurface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.gold,
            indicatorWeight: 2.5,
            labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: [
              const Tab(text: 'Categories'),
              const Tab(text: 'Products'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cart'),
                    if (cartCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textOnGold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Featured',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

@override
Widget build(BuildContext context) {
return BlocBuilder<OrderEntryCubit, OrderEntryState>(
builder: (context, state) {
return Scaffold(
key: _scaffoldKey,
backgroundColor: AppTheme.bgBase,
drawer: _buildSideDrawer(context),
appBar: _buildAppBar(state),
body: _handleBody(state),
);
},
);
}

Widget _handleBody(OrderEntryState state) {
if (state is OrderEntryLoading) {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
SizedBox(
width: 42,
height: 42,
child: CircularProgressIndicator(
color: AppTheme.gold,
strokeWidth: 2,
),
),
const SizedBox(height: 16),
const Text(
'Preparing menu...',
style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
),
],
),
);
}

    if (state is OrderEntryError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.textHint,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed:
                  () => context.read<OrderEntryCubit>().loadInitialData(),
              icon: const Icon(Icons.refresh, color: AppTheme.gold),
              label: const Text(
                'Retry',
                style: TextStyle(color: AppTheme.gold),
              ),
            ),
          ],
        ),
      );
    }

    if (state is OrderEntryLoaded) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryGrid(state),
          _buildProductList(state),
          _buildCartView(state),
          VideoCarouselTab(key: _videoCarouselKey),
        ],
      );
    }

    return const SizedBox();
}

Widget _buildCategoryGrid(OrderEntryLoaded state) {
final cats = state.categories;
final List<Widget> rows = [];
int i = 0;

    while (i < cats.length) {
      final isHeroSlot = (i % 5 == 0);

      if (isHeroSlot) {
        final cat = cats[i];
        rows.add(
          _CategoryCard(
            category: cat,
            index: i,
            isSelected: cat.id == state.selectedCategory.id,
            isHero: true,
            onTap: () {
              _searchController.clear();
              context.read<OrderEntryCubit>().searchProduct('');
              context.read<OrderEntryCubit>().selectCategory(cat);
              _tabController.animateTo(1);
            },
          ),
        );
        i++;
      } else {
        final catA = cats[i];
        final catB = i + 1 < cats.length ? cats[i + 1] : null;
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryCard(
                  category: catA,
                  index: i,
                  isSelected: catA.id == state.selectedCategory.id,
                  isHero: false,
                  onTap: () {
                    _searchController.clear();
                    context.read<OrderEntryCubit>().searchProduct('');
                    context.read<OrderEntryCubit>().selectCategory(catA);
                    _tabController.animateTo(1);
                  },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child:
                    catB != null
                        ? _CategoryCard(
                          category: catB,
                          index: i + 1,
                          isSelected: catB.id == state.selectedCategory.id,
                          isHero: false,
                          onTap: () {
                            _searchController.clear();
                            context.read<OrderEntryCubit>().searchProduct('');
                            context.read<OrderEntryCubit>().selectCategory(
                              catB,
                            );
                            _tabController.animateTo(1);
                          },
                        )
                        : const SizedBox(),
              ),
            ],
          ),
        );
        i += catB != null ? 2 : 1;
      }
      rows.add(SizedBox(height: 12.h));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: rows,
    );
}


Widget _buildProductList(OrderEntryLoaded state) {
return GestureDetector(
onTap: () {
FocusScopeNode currentFocus = FocusScope.of(context);
if (!currentFocus.hasPrimaryFocus) {
currentFocus.unfocus();
}
},
child: Column(
children: [
Padding(
padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
child: TextField(
controller: _searchController,
onChanged: context.read<OrderEntryCubit>().searchProduct,
style: const TextStyle(color: AppTheme.textPrimary),
decoration: InputDecoration(
hintText: 'Search ${state.selectedCategory.name}...',
hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14.sp),
filled: true,
fillColor: AppTheme.bgCard,
prefixIcon: Icon(
Icons.search,
color: AppTheme.textHint,
size: 20.sp,
),
suffixIcon:
_searchController.text.isNotEmpty
? IconButton(
icon: Icon(
Icons.close,
color: AppTheme.textHint,
size: 18.sp,
),
onPressed: () {
_searchController.clear();
context.read<OrderEntryCubit>().searchProduct('');
setState(() {});
},
)
: null,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(14.r),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(14.r),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(14.r),
borderSide: const BorderSide(
color: AppTheme.gold,
width: 1.5,
),
),
contentPadding: EdgeInsets.symmetric(vertical: 12.h),
),
),
),
if (state.currentProducts.isEmpty)
Expanded(child: _buildEmptyState('No items found'))
else
Expanded(
child: ListView.builder(
padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
itemCount: state.currentProducts.length,
itemBuilder: (context, index) {
final product = state.currentProducts[index];
final isInCart = state.cartItems.any(
(i) => i.product.id == product.id,
);
return InkWell(
onTap: () {
FocusManager.instance.primaryFocus?.unfocus();
showProductImagePopup(context, product);
},
child: ProductListItem(
product: product,
isInCart: isInCart,
imageUrl: _foodImg,
onAdd:
() => context.read<OrderEntryCubit>().addToCart(
product,
),
),
);
},
),
),
],
),
);
}


Widget _buildCartView(OrderEntryLoaded state) {
if (state.cartItems.isEmpty) {
return _buildEmptyState(
'Your cart is empty',
icon: Icons.shopping_basket_outlined,
);
}

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            itemCount: state.cartItems.length,
            itemBuilder: (context, index) {
              final item = state.cartItems[index];
              return _CartItem(
                item: item,
                onIncrement:
                    () => context.read<OrderEntryCubit>().updateQuantity(
                      item.uuid,
                      1,
                    ),
                onDecrement:
                    () => context.read<OrderEntryCubit>().updateQuantity(
                      item.uuid,
                      -1,
                    ),
                onRemove:
                    () => context.read<OrderEntryCubit>().removeItem(item.uuid),
                onCustomize:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => BlocProvider.value(
                              value: context.read<OrderEntryCubit>(),
                              child: EditItemScreen(item: item),
                            ),
                      ),
                    ),
              );
            },
          ),
        ),
        _buildCartFooter(state),
      ],
    );
}

Widget _buildCartFooter(OrderEntryLoaded state) {
return Container(
padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
decoration: BoxDecoration(
color: AppTheme.bgSurface,
border: const Border(top: BorderSide(color: AppTheme.bgBorder)),
),
child: Row(
children: [
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Total',
style: TextStyle(
color: AppTheme.textSecondary,
fontSize: 12.sp,
),
),
Text(
'QR ${state.grandTotal.toStringAsFixed(2)}',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 22.sp,
fontWeight: FontWeight.bold,
),
),
],
),
SizedBox(width: 20.w),
Expanded(
child: Container(
decoration: BoxDecoration(
gradient: AppTheme.goldGradient,
borderRadius: BorderRadius.circular(14.r),
boxShadow: [
BoxShadow(
color: AppTheme.gold.withValues(alpha: 0.35),
blurRadius: 14,
offset: const Offset(0, 5),
),
],
),
child: ElevatedButton.icon(
onPressed:
() => Navigator.push(
context,
MaterialPageRoute(
builder:
(_) => BlocProvider.value(
value: context.read<OrderEntryCubit>(),
child: const OrderSummaryScreen(),
),
),
),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.transparent,
shadowColor: Colors.transparent,
padding: EdgeInsets.symmetric(vertical: 16.h),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14.r),
),
),
icon: Icon(
Icons.receipt_outlined,
color: AppTheme.textOnGold,
size: 20.sp,
),
label: Text(
'Place Order',
style: TextStyle(
color: AppTheme.textOnGold,
fontSize: 16.sp,
fontWeight: FontWeight.bold,
),
),
),
),
),
],
),
);
}


Widget _buildSideDrawer(BuildContext context) {
return Drawer(
backgroundColor: AppTheme.bgSurface,
child: Column(
children: [
Container(
padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
decoration: const BoxDecoration(
gradient: LinearGradient(
colors: [Color(0xFF1A1C2C), Color(0xFF21233A)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
),
child: Row(
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
gradient: AppTheme.goldGradient,
borderRadius: BorderRadius.circular(14),
),
child: const Icon(
Icons.restaurant_menu_rounded,
color: AppTheme.textOnGold,
size: 24,
),
),
const SizedBox(width: 14),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Sample Restaurant',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
Text(
'${branchName.isNotEmpty ? branchName : ''} POS System',
style: TextStyle(
color: AppTheme.textSecondary,
fontSize: 12,
),
),
],
),
],
),
),
const SizedBox(height: 16),
DrawerItem(
icon: Icons.category_outlined,
label: 'Manage Categories',
onTap: () {
Navigator.pop(context);
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const ManageCategoriesScreen(),
),
).then((_) {
context.read<OrderEntryCubit>().refreshAllLocalData();
});
},
),
DrawerItem(
icon: Icons.inventory_2_outlined,
label: 'Manage Products',
onTap: () {
Navigator.pop(context);
Navigator.push(
context,
MaterialPageRoute(builder: (_) => const ManageProductsScreen()),
).then((_) {
context.read<OrderEntryCubit>().refreshAllLocalData();
});
},
),
DrawerItem(
icon: Icons.photo_library_outlined,
label: 'Manage Images',
onTap: () {
Navigator.pop(context);
Navigator.push(
context,
MaterialPageRoute(builder: (_) => const ManageImagesScreen()),
).then((_) {
context.read<OrderEntryCubit>().refreshAllLocalData();
if (_tabController.index == 3) {
final state = _videoCarouselKey.currentState;
if (state != null) {
(state as dynamic).reload();
}
}
});
},
),
DrawerItem(
icon: Icons.video_library_outlined,
label: 'Manage Videos',
onTap: () {
Navigator.pop(context);
Navigator.push(
context,
MaterialPageRoute(builder: (_) => const ManageVideosScreen()),
).then((_) {
context.read<OrderEntryCubit>().refreshAllLocalData();
if (_tabController.index == 3) {
final state = _videoCarouselKey.currentState;
if (state != null) {
(state as dynamic).reload();
}
}
});
},
),

          const Spacer(),
          Container(height: 1, color: AppTheme.bgBorder),
          const SizedBox(height: 8),
          DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            iconColor: AppTheme.red,
            labelColor: AppTheme.red,
            onTap: () => _showLogoutDialog(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
}

void _showLogoutDialog(BuildContext context) {
Navigator.pop(context);
showDialog(
context: context,
builder:
(ctx) => Dialog(
backgroundColor: AppTheme.bgCard,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(20),
),
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: AppTheme.red.withValues(alpha: 0.12),
shape: BoxShape.circle,
),
child: const Icon(
Icons.logout_rounded,
color: AppTheme.red,
size: 30,
),
),
const SizedBox(height: 16),
const Text(
'Logout',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
const Text(
'Are you sure you want to logout?',
textAlign: TextAlign.center,
style: TextStyle(
color: AppTheme.textSecondary,
fontSize: 14,
),
),
const SizedBox(height: 24),
Row(
children: [
Expanded(
child: TextButton(
onPressed: () => Navigator.pop(ctx),
style: TextButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
side: const BorderSide(color: AppTheme.bgBorder),
),
),
child: const Text(
'Cancel',
style: TextStyle(color: AppTheme.textSecondary),
),
),
),
const SizedBox(width: 12),
Expanded(
child: ElevatedButton(
onPressed: () async {
await sl<LocalDataSource>().clearAuthToken();
if (context.mounted) {
Navigator.pushNamedAndRemoveUntil(
context,
'kLoginScreen',
(r) => false,
);
}
},
style: ElevatedButton.styleFrom(
backgroundColor: AppTheme.red,
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text(
'Logout',
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
],
),
),
),
);
}

Widget _buildEmptyState(
String msg, {
IconData icon = Icons.search_off_rounded,
}) {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(icon, size: 56, color: AppTheme.textHint),
const SizedBox(height: 14),
Text(
msg,
style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
),
],
),
);
}
}


const List<List<Color>> _kCategoryPalette = [
[Color(0xFFC8973A), Color(0xFFE8C870), Color(0xFFFFE4A0)],
[Color(0xFFD94F3F), Color(0xFFFF8C69), Color(0xFFFFBBA0)],
[Color(0xFF1E8F72), Color(0xFF3ECFA3), Color(0xFFA0FFDE)],
[Color(0xFF6A4FD6), Color(0xFFA882FF), Color(0xFFD4C0FF)],
[Color(0xFF2A6FD4), Color(0xFF62AAFF), Color(0xFFC0DEFF)],
[Color(0xFFBF3F7A), Color(0xFFFF82B8), Color(0xFFFFCCE8)],
[Color(0xFFD47020), Color(0xFFFFAA50), Color(0xFFFFDFAA)],
[Color(0xFF3A9048), Color(0xFF76D670), Color(0xFFBCF0B8)],
];

IconData _iconForCategory(String name) {
final n = name.toLowerCase();
if (n.contains('karak') || n.contains('tea') || n.contains('chai'))
return Icons.emoji_food_beverage_rounded;
if (n.contains('coffee') || n.contains('hot drink') || n.contains('espresso'))
return Icons.local_cafe_rounded;
if (n.contains('cold') ||
n.contains('juice') ||
n.contains('shake') ||
n.contains('smoothie') ||
n.contains('drink'))
return Icons.local_drink_rounded;
if (n.contains('burger') || n.contains('sandwich') || n.contains('wrap'))
return Icons.lunch_dining_rounded;
if (n.contains('pizza')) return Icons.local_pizza_rounded;
if (n.contains('rice') || n.contains('biryani') || n.contains('kabsa'))
return Icons.rice_bowl_rounded;
if (n.contains('salad') || n.contains('veg') || n.contains('green'))
return Icons.eco_rounded;
if (n.contains('dessert') ||
n.contains('sweet') ||
n.contains('cake') ||
n.contains('pastry'))
return Icons.cake_rounded;
if (n.contains('snack') ||
n.contains('starter') ||
n.contains('appetizer') ||
n.contains('side'))
return Icons.tapas_rounded;
if (n.contains('soup') || n.contains('broth'))
return Icons.soup_kitchen_rounded;
if (n.contains('breakfast') || n.contains('egg'))
return Icons.free_breakfast_rounded;
if (n.contains('seafood') || n.contains('fish'))
return Icons.set_meal_rounded;
if (n.contains('chicken') || n.contains('meat') || n.contains('grill'))
return Icons.outdoor_grill_rounded;
if (n.contains('special') || n.contains('chef')) return Icons.star_rounded;
return Icons.restaurant_menu_rounded;
}


class _CategoryCard extends StatefulWidget {
final CategoryModel category;
final int index;
final bool isSelected;
final bool isHero;
final VoidCallback onTap;

const _CategoryCard({
required this.category,
required this.index,
required this.isSelected,
required this.isHero,
required this.onTap,
});

@override
State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
with SingleTickerProviderStateMixin {
late AnimationController _ctrl;
late Animation<double> _fadeAnim;
late Animation<double> _scaleAnim;
bool _pressed = false;

@override
void initState() {
super.initState();
_ctrl = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 400),
);
_fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
_scaleAnim = Tween<double>(
begin: 0.88,
end: 1.0,
).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
Future.delayed(Duration(milliseconds: 20 + widget.index * 55), () {
if (mounted) _ctrl.forward();
});
}

@override
void dispose() {
_ctrl.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final double cardHeight = widget.isHero ? 160.0 : 130.0;
final icon = _iconForCategory(widget.category.name);

    BoxDecoration buildCardDecoration() {
      final List<Color> palette =
          _kCategoryPalette[widget.index % _kCategoryPalette.length];
      final gradStart = palette[0];
      final gradEnd = palette[1];

      ImageProvider? imageProvider;
      final String? path = widget.category.localPath;
      final bool shouldShowLocal = GlobalImageSettings().showLocalImages;
      if (shouldShowLocal && path != null && path.isNotEmpty) {
        if (path.startsWith('/') &&
            path.length < 500 &&
            !path.contains(RegExp(r'[+=\\]'))) {
          final file = File(path);
          if (file.existsSync()) {
            imageProvider = FileImage(file);
          }
        } else {
          try {
            imageProvider = MemoryImage(base64Decode(path.trim()));
          } catch (e) {
            debugPrint(
              "Base64 decode failed for Category ${widget.category.id}: $e",
            );
          }
        }
      }

      if (imageProvider == null &&
          widget.category.imageUrl != null &&
          widget.category.imageUrl!.isNotEmpty) {
        imageProvider = NetworkImage(widget.category.imageUrl!);
      }

      final border = Border.all(
        color:
            widget.isSelected
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
        width: widget.isSelected ? 2 : 1,
      );
      final shadow = BoxShadow(
        color: gradStart.withValues(alpha: widget.isSelected ? 0.55 : 0.3),
        blurRadius: widget.isSelected ? 20 : 10,
        offset: const Offset(0, 5),
      );

      if (imageProvider != null) {
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          border: border,
          boxShadow: [shadow],
        );
      } else {
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [gradStart, gradEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: border,
          boxShadow: [shadow],
        );
      }
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: cardHeight,
              decoration: buildCardDecoration(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  children: [
                    if (widget.category.localPath != null &&
                        widget.category.localPath!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.2),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    Positioned(
                      top: -28,
                      right: -28,
                      child: Ring(
                        size: 130,
                        color: Colors.white,
                        opacity: 0.05,
                      ),
                    ),
                    Positioned(
                      top: -10,
                      right: -10,
                      child: Ring(size: 80, color: Colors.white, opacity: 0.08),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Ring(size: 80, color: Colors.white, opacity: 0.04),
                    ),
                    widget.isHero
                        ? _buildHeroContent(icon)
                        : _buildCompactContent(icon),
                    if (widget.isSelected)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
}

Widget _buildHeroContent(IconData icon) {
return Padding(
padding: const EdgeInsets.all(20),
child: Row(
children: [
Container(
width: 72,
height: 72,
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.18),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: Colors.white.withValues(alpha: 0.25),
width: 1,
),
),
child: Icon(icon, color: Colors.white, size: 36),
),
const SizedBox(width: 18),
Expanded(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
widget.category.name,
style: const TextStyle(
color: Colors.white,
fontSize: 20,
fontWeight: FontWeight.bold,
height: 1.2,
),
),
const SizedBox(height: 6),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 4,
),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(20),
),
child: const Text(
'Tap to explore  →',
style: TextStyle(
color: Colors.white,
fontSize: 11,
fontWeight: FontWeight.w600,
),
),
),
],
),
),
],
),
);
}

Widget _buildCompactContent(IconData icon) {
return Padding(
padding: const EdgeInsets.fromLTRB(16,8,16,16),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 48,
height: 42,
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.18),
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: Colors.white.withValues(alpha: 0.25),
width: 1,
),
),
child: Icon(icon, color: Colors.white, size: 24),
),
const Spacer(),
Text(
widget.category.name,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white,
fontSize: 14,
fontWeight: FontWeight.bold,
height: 1.25,
),
),
const SizedBox(height: 4),
Row(
children: [
Icon(
Icons.arrow_forward_rounded,
color: Colors.white.withValues(alpha: 0.7),
size: 12,
),
const SizedBox(width: 3),
Text(
'View items',
style: TextStyle(
color: Colors.white.withValues(alpha: 0.7),
fontSize: 10,
fontWeight: FontWeight.w500,
),
),
],
),
],
),
);
}
}


class _CartItem extends StatelessWidget {
final CartItem item;
final VoidCallback onIncrement;
final VoidCallback onDecrement;
final VoidCallback onRemove;
final VoidCallback onCustomize;

const _CartItem({
required this.item,
required this.onIncrement,
required this.onDecrement,
required this.onRemove,
required this.onCustomize,
});

@override
Widget build(BuildContext context) {
final cartImgWidth = 120.w;
final cartImgHeight = 72.h;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: cartImgWidth,
                height: cartImgHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  color: AppTheme.bgCardElevated,
                ),
                clipBehavior: Clip.hardEdge,
                child: _buildProductImage(),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.modifiers.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      ...item.modifiers.map(
                        (m) => Text(
                          '+ ${m.name}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ],
                    if (item.note.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Note: ${item.note}',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 11.sp,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'QR ${item.total.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCardElevated,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    QtyBtn(
                      icon: Icons.remove,
                      onTap: onDecrement,
                      color: AppTheme.red,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Text(
                        '${item.quantity}'.padLeft(2, '0'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                    QtyBtn(
                      icon: Icons.add,
                      onTap: onIncrement,
                      color: AppTheme.green,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCustomize,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.bgBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  icon: Icon(
                    Icons.tune_rounded,
                    color: AppTheme.blue,
                    size: 16.sp,
                  ),
                  label: Text(
                    'Customize',
                    style: TextStyle(color: AppTheme.blue, fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.textHint,
                  size: 20.sp,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.red.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
}

Widget _buildProductImage() {
final String? path = item.product.localPath;
final bool shouldShowLocal = GlobalImageSettings().showLocalImages;
if (shouldShowLocal && path != null && path.isNotEmpty) {
if (path.startsWith('/') && path.length < 500) {
final file = File(path);
if (file.existsSync()) {
return Image.file(
file,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) => _buildUrlFallback(),
);
}
} else {
try {
final cleanBase64 = path.trim().split(',').last;
return Image.memory(
base64Decode(cleanBase64),
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) => _buildUrlFallback(),
);
} catch (e) {
debugPrint("Cart image Base64 decode failed: $e");
}
}
}

    return _buildUrlFallback();
}

Widget _buildUrlFallback() {
if (item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty) {
return Image.network(
item.product.imageUrl!,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) => _buildPlaceholder(),
);
}
return Image.network(
'https://images.unsplash.com/photo-1606787366850-de6330128bfc?q=80&w=300&auto=format&fit=crop',
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) => _buildPlaceholder(),
);
}

Widget _buildPlaceholder() {
return Container(
color: AppTheme.bgCardElevated,
alignment: Alignment.center,
child: Icon(Icons.fastfood, color: AppTheme.textHint, size: 28.sp),
);
}
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/app_theme.dart';
import '../../cubit/order_entry/order_entry_cubit.dart';
import '../../cubit/order_entry/order_entry_state.dart';

class OrderSummaryScreen extends StatefulWidget {
const OrderSummaryScreen({super.key});

@override
State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
final TextEditingController _referenceController =
TextEditingController();
final TextEditingController _pinController = TextEditingController();
final _formKey = GlobalKey<FormState>();
final FocusNode _referenceFocusNode = FocusNode();
bool _obscurePin = true;

@override
void initState() {
super.initState();
WidgetsBinding.instance.addPostFrameCallback((_) {
_referenceFocusNode.requestFocus();
});
}

@override
void dispose() {
_referenceController.dispose();
_pinController.dispose();
_referenceFocusNode.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: AppTheme.bgBase,
appBar: AppBar(
backgroundColor: AppTheme.bgSurface,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back_ios_new,
color: AppTheme.textPrimary, size: 20),
onPressed: () => Navigator.pop(context),
),
title: const Text(
'Order Summary',
style: TextStyle(
color: AppTheme.textPrimary,
fontWeight: FontWeight.bold,
fontSize: 17),
),
centerTitle: true,
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(height: 1, color: AppTheme.bgBorder),
),
),
body: BlocConsumer<OrderEntryCubit, OrderEntryState>(
listener: (context, state) {
if (state is OrderSubmissionSuccess) {
_showSuccessDialog(context, state);
} else if (state is OrderEntryError) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(state.message),
backgroundColor: AppTheme.red,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10)),
margin: const EdgeInsets.all(16),
),
);
}
},
builder: (context, state) {
if (state is OrderEntryLoading) {
return const Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
CircularProgressIndicator(
color: AppTheme.gold,
strokeWidth: 2,
),
SizedBox(height: 16),
Text('Sending to kitchen...',
style: TextStyle(
color: AppTheme.textSecondary, fontSize: 14)),
],
),
);
}

          if (state is! OrderEntryLoaded) return const SizedBox();

          return Column(
            children: [
              // Items list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = state.cartItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border:
                        Border.all(color: AppTheme.bgBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.quantity}×',
                              style: const TextStyle(
                                color: AppTheme.textOnGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight:
                                        FontWeight.w600)),
                                if (item.modifiers.isNotEmpty)
                                  ...item.modifiers.map(
                                        (m) => Text('+ ${m.name}',
                                        style: const TextStyle(
                                            color: AppTheme
                                                .textSecondary,
                                            fontSize: 12)),
                                  ),
                                if (item.note.isNotEmpty)
                                  Text('Note: ${item.note}',
                                      style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      )),
                              ],
                            ),
                          ),
                          Text(
                            'QR ${item.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Checkout panel
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  border: const Border(
                      top: BorderSide(color: AppTheme.bgBorder)),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Grand total
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E1E0A),
                              Color(0xFF2A2510)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.gold
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14)),
                            Text(
                              'QR ${state.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Reference
                      _buildInputLabel('Order Reference'),
                      const SizedBox(height: 6),
                      _buildFormField(
                        controller: _referenceController,
                        focusNode: _referenceFocusNode,
                        hint: 'Customer name or table number',
                        icon: Icons.person_outline_rounded,
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // PIN
                      _buildInputLabel('Waitress PIN'),
                      const SizedBox(height: 6),
                      _buildFormField(
                        controller: _pinController,
                        hint: '••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePin,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'PIN required' : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textHint,
                            size: 18,
                          ),
                          onPressed: () => setState(
                                  () => _obscurePin = !_obscurePin),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Place order button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                              AppTheme.gold.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _placeOrder(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14)),
                          ),
                          icon: const Icon(
                              Icons.send_rounded,
                              color: AppTheme.textOnGold,
                              size: 20),
                          label: const Text(
                            'SEND TO KITCHEN',
                            style: TextStyle(
                              color: AppTheme.textOnGold,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
}

Widget _buildInputLabel(String text) => Text(
text,
style: const TextStyle(
color: AppTheme.textSecondary,
fontSize: 12,
fontWeight: FontWeight.w500),
);

Widget _buildFormField({
required TextEditingController controller,
required String hint,
required IconData icon,
FocusNode? focusNode,
bool obscure = false,
TextInputType? keyboardType,
FormFieldValidator<String>? validator,
Widget? suffixIcon,
}) {
return TextFormField(
controller: controller,
focusNode: focusNode,
obscureText: obscure,
keyboardType: keyboardType,
style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
validator: validator,
decoration: InputDecoration(
hintText: hint,
hintStyle:
const TextStyle(color: AppTheme.textHint, fontSize: 13),
filled: true,
fillColor: AppTheme.bgCard,
prefixIcon: Icon(icon, color: AppTheme.textHint, size: 18),
suffixIcon: suffixIcon,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide:
const BorderSide(color: AppTheme.gold, width: 1.5),
),
errorBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.red),
),
contentPadding: const EdgeInsets.symmetric(vertical: 14),
),
);
}

void _placeOrder(BuildContext context) {
_referenceFocusNode.unfocus();
context.read<OrderEntryCubit>().submitOrder(
customerId: _referenceController.text,
customerName: _referenceController.text,
orderType: 2,
);
}

void _showSuccessDialog(
BuildContext context, OrderSubmissionSuccess state) {
showDialog(
context: context,
barrierDismissible: false,
builder: (ctx) => Dialog(
backgroundColor: AppTheme.bgCard,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22)),
child: Padding(
padding: const EdgeInsets.all(28),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
gradient: AppTheme.greenGradient,
shape: BoxShape.circle,
boxShadow: [
BoxShadow(
color: AppTheme.green.withValues(alpha: 0.4),
blurRadius: 20,
offset: const Offset(0, 6),
),
],
),
child: const Icon(Icons.check_rounded,
color: Colors.white, size: 36),
),
const SizedBox(height: 20),
const Text('Order Sent!',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 22,
fontWeight: FontWeight.bold,
)),
const SizedBox(height: 8),
Text(
'KOT #${state.response.kitchenSaleId}',
style: const TextStyle(
color: AppTheme.gold,
fontSize: 16,
fontWeight: FontWeight.bold),
),
const SizedBox(height: 6),
const Text(
'Order successfully pushed\nto the kitchen.',
textAlign: TextAlign.center,
style: TextStyle(
color: AppTheme.textSecondary, height: 1.5),
),
const SizedBox(height: 28),
Container(
decoration: BoxDecoration(
gradient: AppTheme.goldGradient,
borderRadius: BorderRadius.circular(12),
),
child: ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.transparent,
shadowColor: Colors.transparent,
minimumSize: const Size(double.infinity, 48),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12)),
),
onPressed: () {
Navigator.pop(ctx);
context.read<OrderEntryCubit>().resetAfterSubmission();
Navigator.pop(context);
},
child: const Text('New Order',
style: TextStyle(
color: AppTheme.textOnGold,
fontWeight: FontWeight.bold,
fontSize: 15,
)),
),
),
],
),
),
),
);
}
}import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../cubit/running_orders/running_orders_cubit.dart';
import '../../cubit/running_orders/running_orders_state.dart';

class RunningOrdersScreen extends StatelessWidget {
const RunningOrdersScreen({super.key});

@override
Widget build(BuildContext context) {
return BlocProvider(
create: (_) => sl<RunningOrdersCubit>()..fetchRunningOrders(),
child: const _RunningOrdersView(),
);
}
}

class _RunningOrdersView extends StatefulWidget {
const _RunningOrdersView();

@override
State<_RunningOrdersView> createState() => _RunningOrdersViewState();
}

class _RunningOrdersViewState extends State<_RunningOrdersView> {
Timer? _timer;

@override
void initState() {
super.initState();
_timer = Timer.periodic(const Duration(seconds: 60), (_) {
if (mounted) {
context
.read<RunningOrdersCubit>()
.fetchRunningOrders(isBackgroundRefresh: true);
}
});
}

@override
void dispose() {
_timer?.cancel();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: AppTheme.bgBase,
appBar: AppBar(
backgroundColor: AppTheme.bgSurface,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back_ios_new,
color: AppTheme.textPrimary, size: 20),
onPressed: () => Navigator.pop(context),
),
title: const Text(
'Running Orders',
style: TextStyle(
color: AppTheme.textPrimary,
fontWeight: FontWeight.bold,
fontSize: 17),
),
centerTitle: true,
actions: [
BlocBuilder<RunningOrdersCubit, RunningOrdersState>(
builder: (context, state) => IconButton(
icon: const Icon(Icons.refresh_rounded,
color: AppTheme.textSecondary, size: 22),
onPressed: () => context
.read<RunningOrdersCubit>()
.fetchRunningOrders(),
),
),
],
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(height: 1, color: AppTheme.bgBorder),
),
),
body: BlocBuilder<RunningOrdersCubit, RunningOrdersState>(
builder: (context, state) {
if (state is RunningOrdersLoading) {
return const Center(
child: CircularProgressIndicator(
color: AppTheme.gold, strokeWidth: 2),
);
}

          if (state is RunningOrdersError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppTheme.textHint, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message,
                      style: const TextStyle(
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context
                        .read<RunningOrdersCubit>()
                        .fetchRunningOrders(),
                    icon:
                    const Icon(Icons.refresh, color: AppTheme.gold),
                    label: const Text('Retry',
                        style: TextStyle(color: AppTheme.gold)),
                  ),
                ],
              ),
            );
          }

          if (state is RunningOrdersLoaded) {
            if (state.orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 52, color: AppTheme.textHint),
                    SizedBox(height: 14),
                    Text('No active orders',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.orders.length,
              itemBuilder: (context, index) {
                return _OrderCard(
                  order: state.orders[index],
                  index: index,
                  onPrint: (orderId) {
                    context.read<RunningOrdersCubit>().printOrder(
                      orderId,
                      onSuccess: (msg) =>
                          _showSnack(context, msg, isSuccess: true),
                      onError: (err) =>
                          _showSnack(context, err, isSuccess: false),
                    );
                  },
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
}

void _showSnack(BuildContext context, String msg,
{required bool isSuccess}) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(msg),
backgroundColor: isSuccess ? AppTheme.green : AppTheme.red,
behavior: SnackBarBehavior.floating,
shape:
RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
margin: const EdgeInsets.all(16),
),
);
}
}

// ── ORDER CARD ─────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
final dynamic order;
final int index;
final ValueChanged<int> onPrint;

const _OrderCard({
required this.order,
required this.index,
required this.onPrint,
});

@override
State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
with SingleTickerProviderStateMixin {
late final AnimationController _ctrl;
bool _expanded = false;

@override
void initState() {
super.initState();
_ctrl = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 280 + 50),
);
Future.delayed(
Duration(milliseconds: widget.index * 60),
() { if (mounted) _ctrl.forward(); },
);
}

@override
void dispose() {
_ctrl.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return FadeTransition(
opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
child: SlideTransition(
position: Tween<Offset>(
begin: const Offset(0, 0.1),
end: Offset.zero,
).animate(
CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
child: Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: AppTheme.bgBorder),
),
child: Column(
children: [
// Header row
InkWell(
onTap: () => setState(() => _expanded = !_expanded),
borderRadius: BorderRadius.circular(16),
child: Padding(
padding: const EdgeInsets.all(14),
child: Row(
children: [
// Status dot
Container(
width: 8,
height: 8,
decoration: const BoxDecoration(
color: AppTheme.green,
shape: BoxShape.circle,
),
),
const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.order.customerName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.order.saleNo,
                              style: const TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Total
                      Text(
                        'QR ${widget.order.totalPayable.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Print
                      _PrintBtn(
                          onTap: () => widget.onPrint(widget.order.id)),
                      const SizedBox(width: 6),

                      // Expand chevron
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _expanded ? 0.5 : 0,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textHint,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded details
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgBase,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                    border: const Border(
                        top: BorderSide(color: AppTheme.bgBorder)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ORDER DETAILS',
                        style: TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.order.details
                          .map<Widget>((item) => Padding(
                        padding:
                        const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppTheme.goldGradient,
                                borderRadius:
                                BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.qty}×',
                                style: const TextStyle(
                                  color: AppTheme.textOnGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.menuName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              item.price.toStringAsFixed(2),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
}

class _PrintBtn extends StatelessWidget {
final VoidCallback onTap;

const _PrintBtn({required this.onTap});

@override
Widget build(BuildContext context) {
return InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(8),
child: Container(
padding:
const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
decoration: BoxDecoration(
color: AppTheme.blue.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: AppTheme.blue.withValues(alpha: 0.3)),
),
child: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.print_outlined,
color: AppTheme.blue, size: 14),
SizedBox(width: 4),
Text('Print',
style: TextStyle(
color: AppTheme.blue,
fontSize: 12,
fontWeight: FontWeight.bold)),
],
),
),
);
}
}import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';

class EditCategoryScreen extends StatefulWidget {
final CategoryModel category;

const EditCategoryScreen({super.key, required this.category});

@override
State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
String? _selectedImageBase64;
bool _showLocalImage = true;

@override
void initState() {
super.initState();
_selectedImageBase64 = widget.category.localPath;
_showLocalImage = widget.category.showLocalImage;
}

Future<void> _pickImage() async {
final XFile? image = await ImagePicker().pickImage(
source: ImageSource.gallery,
imageQuality: 50,
maxWidth: 800,
);
if (image != null) {
final bytes = await image.readAsBytes();
setState(() {
_selectedImageBase64 = base64Encode(bytes);
});
}
}

@override
Widget build(BuildContext context) {
return BlocProvider.value(
value: sl<CategoriesCubit>(),
child: Builder(
builder: (innerContext) {
return Scaffold(
backgroundColor: AppTheme.bgBase,
appBar: AppBar(
backgroundColor: AppTheme.bgSurface,
elevation: 0,
leading: IconButton(
icon: const Icon(
Icons.arrow_back_ios_new,
color: AppTheme.textPrimary,
size: 20,
),
onPressed: () => Navigator.pop(context),
),
title: const Text(
'Edit Category',
style: TextStyle(
color: AppTheme.textPrimary,
fontWeight: FontWeight.bold,
fontSize: 18,
),
),
centerTitle: true,
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(height: 1, color: AppTheme.bgBorder),
),
),
body: BlocListener<CategoriesCubit, CategoriesState>(
listener: (context, state) {
if (state is CategoryActionSuccess) {
Navigator.pop(context);
}
},
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Category Image',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.bgBorder),
                          color: AppTheme.bgCardElevated,
                        ),
                        child: _selectedImageBase64 != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                  child: _buildImagePreview()),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.45),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit,
                                          color: Colors.white,
                                          size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tap to change image',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: IconButton(
                                  onPressed: () => setState(
                                          () => _selectedImageBase64 = null),
                                  icon: const CircleAvatar(
                                    backgroundColor: AppTheme.red,
                                    radius: 18,
                                    child: Icon(Icons.delete_outline,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_rounded,
                                color: AppTheme.gold, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Tap to select image',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildShowLocalImageToggle(),

                    const SizedBox(height: 32),

                    const Text(
                      'Category Details',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      icon: Icons.drive_file_rename_outline,
                      label: 'Category Name',
                      value: widget.category.name,
                    ),
                    const SizedBox(height: 40),

                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          innerContext.read<CategoriesCubit>().updateCategory(
                            widget.category.id,
                            widget.category.name,
                            imageBase64: _selectedImageBase64,
                            showLocalImage: _showLocalImage,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: AppTheme.textOnGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
}


Widget _buildShowLocalImageToggle() {
final hasLocalImage =
_selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_showLocalImage)
                  ? AppTheme.gold.withValues(alpha: 0.15)
                  : AppTheme.bgCardElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.photo_library_outlined,
                key: ValueKey(_showLocalImage),
                size: 18,
                color: (_showLocalImage)
                    ? AppTheme.gold
                    : AppTheme.textHint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Show Local Image',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    key: ValueKey('$_showLocalImage-$hasLocalImage'),
                    _showLocalImage
                        ? (hasLocalImage
                            ? 'Local image will show on main screen'
                            : 'Ready for local image (to upload)')
                        : (hasLocalImage
                            ? 'Network/gradient will show on main screen'
                            : 'Network/gradient will show on main screen'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _showLocalImage,
            onChanged: (val) {
              setState(() {
                _showLocalImage = val;
              });
            },
            activeColor: AppTheme.gold,
            inactiveThumbColor: AppTheme.textHint,
            inactiveTrackColor: AppTheme.bgBorder,
          ),
        ],
      ),
    );
}


Widget _buildReadOnlyField({
required IconData icon,
required String label,
required String value,
}) {
return Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
decoration: BoxDecoration(
color: AppTheme.bgCardElevated,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: AppTheme.bgBorder),
),
child: Row(
children: [
Icon(icon, color: AppTheme.gold, size: 20),
const SizedBox(width: 12),
Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label,
style: const TextStyle(
color: AppTheme.textSecondary, fontSize: 11)),
const SizedBox(height: 2),
Text(value,
style: const TextStyle(
color: AppTheme.textPrimary, fontSize: 16)),
],
),
],
),
);
}

Widget _buildImagePreview() {
if (_selectedImageBase64 == null || _selectedImageBase64!.isEmpty) {
return const SizedBox();
}

    if (_selectedImageBase64!.startsWith('/')) {
      final file = File(_selectedImageBase64!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    try {
      final cleanBase64 = _selectedImageBase64!.trim();
      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child:
          Icon(Icons.broken_image, color: AppTheme.red, size: 40),
        ),
      );
    } catch (e) {
      return const Center(
        child:
        Icon(Icons.broken_image, color: AppTheme.red, size: 40),
      );
    }
}
}import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';
import 'edit_category_screen.dart';

class ManageCategoriesScreen extends StatelessWidget {
const ManageCategoriesScreen({super.key});

@override
Widget build(BuildContext context) {
return BlocProvider(
create: (_) => sl<CategoriesCubit>()..fetchCategories(),
child: const _ManageCategoriesView(),
);
}
}

class _ManageCategoriesView extends StatefulWidget {
const _ManageCategoriesView();

@override
State<_ManageCategoriesView> createState() => _ManageCategoriesViewState();
}

class _ManageCategoriesViewState extends State<_ManageCategoriesView>
with SingleTickerProviderStateMixin {
late AnimationController _fabAnimController;

@override
void initState() {
super.initState();
_fabAnimController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 200),
);
}

@override
void dispose() {
_fabAnimController.dispose();
super.dispose();
}



void _showEditDialog(BuildContext context, CategoryModel cat) {
_showCategoryDialog(
context,
title: 'Edit Category',
initialValue: cat.name,
initialImageBase64: cat.localPath,
onConfirm: (name, image) {
context.read<CategoriesCubit>().updateCategory(cat.id, name, imageBase64: image);
},
);
}

void _showCategoryDialog(
BuildContext outerContext, {
required String title,
String initialValue = '',
String? initialImageBase64,
required Function(String name, String? imageBase64) onConfirm,
}) {
final controller = TextEditingController(text: initialValue);
final formKey = GlobalKey<FormState>();
String? selectedImageBase64 = initialImageBase64;

    showDialog(
      context: outerContext,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          color: AppTheme.textOnGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  StatefulBuilder(
                    builder: (ctx, setState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Image',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.bgBorder),
                            color: AppTheme.bgCardElevated,
                          ),
                          child: selectedImageBase64 != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.memory(
                                  base64Decode(selectedImageBase64!),
                                  fit: BoxFit.cover,
                                ),
                              )
                              : GestureDetector(
                                onTap: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (image != null) {
                                    final bytes = await image.readAsBytes();
                                    final base64Image = base64Encode(bytes);
                                    setState(() {
                                      selectedImageBase64 = base64Image;
                                    });
                                  }
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_rounded,
                                        color: AppTheme.gold, size: 40),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap to select image',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                        if (selectedImageBase64 != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() => selectedImageBase64 = null);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.red.withValues(alpha: 0.15),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.delete_outline, color: AppTheme.red),
                              label: const Text(
                                'Remove image',
                                style: TextStyle(color: AppTheme.red),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.bgCardElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.bgBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.bgBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: AppTheme.gold, width: 1.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.drive_file_rename_outline,
                        color: AppTheme.gold,
                        size: 20,
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.bgBorder),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(ctx);
                                onConfirm(controller.text, selectedImageBase64);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                color: AppTheme.textOnGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
}

void _showDeleteDialog(BuildContext context, CategoryModel cat) {
showDialog(
context: context,
builder: (ctx) => Dialog(
backgroundColor: AppTheme.bgCard,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: AppTheme.red.withValues(alpha: 0.15),
shape: BoxShape.circle,
),
child: const Icon(
Icons.delete_outline_rounded,
color: AppTheme.red,
size: 32,
),
),
const SizedBox(height: 16),
const Text(
'Delete Category',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
Text(
'Remove "${cat.name}" from the menu?\nThis cannot be undone.',
textAlign: TextAlign.center,
style: const TextStyle(
color: AppTheme.textSecondary,
fontSize: 14,
height: 1.5,
),
),
const SizedBox(height: 24),
Row(
children: [
Expanded(
child: TextButton(
onPressed: () => Navigator.pop(ctx),
style: TextButton.styleFrom(
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
side: const BorderSide(color: AppTheme.bgBorder),
),
),
child: const Text(
'Cancel',
style: TextStyle(color: AppTheme.textSecondary),
),
),
),
const SizedBox(width: 12),
Expanded(
child: ElevatedButton(
onPressed: () {
Navigator.pop(ctx);
context.read<CategoriesCubit>().deleteCategory(cat.id);
},
style: ElevatedButton.styleFrom(
backgroundColor: AppTheme.red,
padding: const EdgeInsets.symmetric(vertical: 14),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text(
'Delete',
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
],
),
),
),
);
}


@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: AppTheme.bgBase,
appBar: AppBar(
backgroundColor: AppTheme.bgSurface,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back_ios_new,
color: AppTheme.textPrimary, size: 20),
onPressed: () => Navigator.pop(context),
),
title: const Text(
'Manage Categories',
style: TextStyle(
color: AppTheme.textPrimary,
fontWeight: FontWeight.bold,
fontSize: 18,
),
),
centerTitle: true,
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(height: 1, color: AppTheme.bgBorder),
),
),
body: BlocConsumer<CategoriesCubit, CategoriesState>(
listener: (context, state) {
if (state is CategoryActionSuccess) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Row(
children: [
const Icon(Icons.check_circle_outline,
color: Colors.white, size: 18),
const SizedBox(width: 8),
Text(state.message),
],
),
backgroundColor: AppTheme.green,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10)),
margin: const EdgeInsets.all(16),
),
);
} else if (state is CategoryActionError) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(state.message),
backgroundColor: AppTheme.red,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10)),
margin: const EdgeInsets.all(16),
),
);
}
},
builder: (context, state) => _buildBody(context, state),
),
);
}


Widget _buildBody(BuildContext context, CategoriesState state) {
List<CategoryModel> categories = [];
bool isActionLoading = false;

    if (state is CategoriesLoaded) categories = state.categories;
    if (state is CategoryActionLoading) {
      categories = state.categories;
      isActionLoading = true;
    }
    if (state is CategoryActionSuccess) categories = state.categories;
    if (state is CategoryActionError) categories = state.categories;

    if (state is CategoriesLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppTheme.gold,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading categories...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state is CategoriesError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
            const SizedBox(height: 12),
            Text(
              state.message,
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () =>
                  context.read<CategoriesCubit>().fetchCategories(),
              icon: const Icon(Icons.refresh, color: AppTheme.gold),
              label: const Text('Retry',
                  style: TextStyle(color: AppTheme.gold)),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        categories.isEmpty
            ? _buildEmptyState(context)
            : _buildCategoryList(context, categories),

        if (isActionLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: AppTheme.gold,
              backgroundColor: AppTheme.bgBorder,
              minHeight: 2,
            ),
          ),
      ],
    );
}

Widget _buildEmptyState(BuildContext context) {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
color: AppTheme.bgCard,
shape: BoxShape.circle,
border: Border.all(color: AppTheme.bgBorder),
),
child: const Icon(
Icons.category_outlined,
size: 48,
color: AppTheme.textHint,
),
),
const SizedBox(height: 20),
const Text(
'No categories yet',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
const Text(
'Tap "New Category" below to get started.',
style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
),
],
),
);
}

Widget _buildCategoryList(
BuildContext context, List<CategoryModel> categories) {
return ListView.builder(
padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
itemCount: categories.length,
itemBuilder: (context, index) {
final cat = categories[index];
return _CategoryCard(
category: cat,
index: index,
onEdit: () => _showEditDialog(context, cat),
onDelete: () => _showDeleteDialog(context, cat),
);
},
);
}
}


class _CategoryCard extends StatefulWidget {
final CategoryModel category;
final int index;
final VoidCallback onEdit;
final VoidCallback onDelete;

const _CategoryCard({
required this.category,
required this.index,
required this.onEdit,
required this.onDelete,
});

@override
State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
with SingleTickerProviderStateMixin {
late final AnimationController _controller;
late final Animation<double> _fadeAnim;
late final Animation<Offset> _slideAnim;

@override
void initState() {
super.initState();
_controller = AnimationController(
vsync: this,
duration: Duration(milliseconds: 300 + (widget.index * 60)),
);
_fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
_slideAnim = Tween<Offset>(
begin: const Offset(0, 0.15),
end: Offset.zero,
).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return FadeTransition(
opacity: _fadeAnim,
child: SlideTransition(
position: _slideAnim,
child: Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: AppTheme.bgBorder),
),
child: Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(16),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => EditCategoryScreen(category: widget.category),
),
).then((_){
context.read<CategoriesCubit>().fetchCategories();
});
},
child: Padding(
padding:
const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
child: Row(
children: [
if (widget.category.showLocalImage && widget.category.localPath != null && widget.category.localPath!.isNotEmpty)
ClipRRect(
borderRadius: BorderRadius.circular(10),
child: Image.memory(
base64Decode(widget.category.localPath!),
width: 50,
height: 50,
fit: BoxFit.cover,
),
)
else
Container(
width: 50,
height: 50,
decoration: BoxDecoration(
gradient: AppTheme.goldGradient,
borderRadius: BorderRadius.circular(10),
),
alignment: Alignment.center,
child: const Icon(
Icons.category_rounded,
color: AppTheme.textOnGold,
size: 24,
),
),
const SizedBox(width: 14),

                    Expanded(
                      child: Text(
                        widget.category.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    _ActionIconBtn(
                      icon: Icons.edit_rounded,
                      color: AppTheme.blue,
                      onTap: widget.onEdit,
                    ),
                    const SizedBox(width: 8),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
}
}

class _ActionIconBtn extends StatelessWidget {
final IconData icon;
final Color color;
final VoidCallback onTap;

const _ActionIconBtn({
required this.icon,
required this.color,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(8),
child: Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(8),
),
child: Icon(icon, color: color, size: 18),
),
);
}
}import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../data/data_sources/local_data_sources.dart';


class ManageImagesScreen extends StatefulWidget {
const ManageImagesScreen({super.key});

@override
State<ManageImagesScreen> createState() => _ManageImagesScreenState();
}

class _ManageImagesScreenState extends State<ManageImagesScreen> {
List<String> _paths = [];
bool _loading = true;
bool _gridView = true;
final LocalDataSource _localDataSource = sl<LocalDataSource>();

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
final list = await _localDataSource.getImagePaths();
if (mounted) setState(() { _paths = list; _loading = false; });
}

Future<void> _addImages() async {
final result = await FilePicker.pickFiles(
type: FileType.custom,
allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'],
allowMultiple: true,
);

    if (result == null || result.files.isEmpty) return;

    final current = await _localDataSource.getImagePaths();
    for (final f in result.files) {
      if (f.path != null && !current.contains(f.path)) {
        current.add(f.path!);
      }
    }
    await _localDataSource.saveImagePaths(current);
    await _load();
}

Future<void> _delete(String path) async {
final confirmed = await _confirmDelete(context, 'Remove this image?');
if (!confirmed) return;
final current = await _localDataSource.getImagePaths();
current.remove(path);
await _localDataSource.saveImagePaths(current);
await _load();
}

Future<bool> _confirmDelete(BuildContext ctx, String message) async {
return await showDialog<bool>(
context: ctx,
builder: (_) => AlertDialog(
backgroundColor: const Color(0xFF1A1C30),
shape:
RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: const Text('Confirm',
style: TextStyle(color: Colors.white, fontSize: 16)),
content: Text(message,
style: const TextStyle(color: Color(0xFFB0B0C8))),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx, false),
child: const Text('Cancel',
style: TextStyle(color: Color(0xFF6A6D8A))),
),
TextButton(
onPressed: () => Navigator.pop(ctx, true),
child: const Text('Remove',
style: TextStyle(color: Color(0xFFC8973A))),
),
],
),
) ??
false;
}

void _showFullImage(BuildContext ctx, int index) {
Navigator.push(
ctx,
MaterialPageRoute(
builder: (_) => _FullImageView(
paths: _paths,
initialIndex: index,
onDelete: (path) async {
Navigator.pop(ctx);
final current = await _localDataSource.getImagePaths();
current.remove(path);
await _localDataSource.saveImagePaths(current);
await _load();
},
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF0E0F1C),
appBar: AppBar(
backgroundColor: const Color(0xFF12141F),
foregroundColor: Colors.white,
title: const Text(
'Manage Images',
style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
),
centerTitle: true,
elevation: 0,
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(height: 1, color: const Color(0xFF1E2035)),
),
actions: [
IconButton(
onPressed: () => setState(() => _gridView = !_gridView),
icon: Icon(
_gridView ? Icons.view_list_outlined : Icons.grid_view_outlined,
color: const Color(0xFFC8973A),
),
),
IconButton(
onPressed: _addImages,
icon:
const Icon(Icons.add_circle_outline, color: Color(0xFFC8973A)),
tooltip: 'Add Images',
),
],
),
body: _loading
? const Center(
child: CircularProgressIndicator(color: Color(0xFFC8973A)),
)
: _paths.isEmpty
? _buildEmpty()
: _gridView
? _buildGrid()
: _buildList(),
floatingActionButton: FloatingActionButton.extended(
onPressed: _addImages,
backgroundColor: const Color(0xFFC8973A),
foregroundColor: Colors.black,
icon: const Icon(Icons.add_photo_alternate_outlined),
label: const Text('Add Images',
style: TextStyle(fontWeight: FontWeight.bold)),
),
);
}

Widget _buildEmpty() {
return Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.photo_library_outlined,
size: 64, color: Colors.white.withValues(alpha: 0.08)),
const SizedBox(height: 16),
const Text('No images added yet',
style: TextStyle(color: Color(0xFF4A4D6A), fontSize: 15)),
const SizedBox(height: 8),
const Text('Tap the button below to pick images from your device',
textAlign: TextAlign.center,
style: TextStyle(color: Color(0xFF2E3050), fontSize: 12)),
],
),
);
}

Widget _buildGrid() {
return GridView.builder(
padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 3,
crossAxisSpacing: 8,
mainAxisSpacing: 8,
),
itemCount: _paths.length,
itemBuilder: (context, index) {
return GestureDetector(
onTap: () => _showFullImage(context, index),
onLongPress: () => _delete(_paths[index]),
child: Stack(
fit: StackFit.expand,
children: [
ClipRRect(
borderRadius: BorderRadius.circular(12),
child: Image.file(
File(_paths[index]),
fit: BoxFit.cover,
errorBuilder: (_, __, ___) => Container(
color: const Color(0xFF1A1C30),
child: const Icon(Icons.broken_image_outlined,
color: Color(0xFF4A4D6A)),
),
),
),
Positioned(
top: 4,
right: 4,
child: GestureDetector(
onTap: () => _delete(_paths[index]),
child: Container(
padding: const EdgeInsets.all(4),
decoration: BoxDecoration(
color: Colors.black.withValues(alpha: 0.6),
shape: BoxShape.circle,
),
child: const Icon(Icons.close,
color: Colors.white70, size: 14),
),
),
),
],
),
);
},
);
}

Widget _buildList() {
return ReorderableListView.builder(
padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
itemCount: _paths.length,
onReorder: (oldIndex, newIndex) async {
setState(() {
if (newIndex > oldIndex) newIndex--;
final item = _paths.removeAt(oldIndex);
_paths.insert(newIndex, item);
});
await _localDataSource.saveImagePaths(_paths);
},
itemBuilder: (context, index) {
final path = _paths[index];
final name = path.split('/').last;

        return Container(
          key: ValueKey(path),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141628),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2035), width: 1),
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A1C30),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Color(0xFF4A4D6A)),
                  ),
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Color(0xFFD0D0E8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _showFullImage(context, index),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFF6A3A3A), size: 20),
                  onPressed: () => _delete(path),
                ),
                const Icon(Icons.drag_handle_rounded,
                    color: Color(0xFF2E3050), size: 20),
              ],
            ),
          ),
        );
      },
    );
}
}


class _FullImageView extends StatefulWidget {
final List<String> paths;
final int initialIndex;
final void Function(String path) onDelete;

const _FullImageView({
required this.paths,
required this.initialIndex,
required this.onDelete,
});

@override
State<_FullImageView> createState() => _FullImageViewState();
}

class _FullImageViewState extends State<_FullImageView> {
late PageController _ctrl;
late int _index;

@override
void initState() {
super.initState();
_index = widget.initialIndex;
_ctrl = PageController(initialPage: _index);
}

@override
void dispose() {
_ctrl.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.black,
appBar: AppBar(
backgroundColor: Colors.black,
foregroundColor: Colors.white,
title: Text(
'${_index + 1} / ${widget.paths.length}',
style: const TextStyle(fontSize: 14, color: Colors.white54),
),
centerTitle: true,
actions: [
IconButton(
icon: const Icon(Icons.delete_outline, color: Color(0xFFC8973A)),
onPressed: () => widget.onDelete(widget.paths[_index]),
),
],
),
body: PageView.builder(
controller: _ctrl,
itemCount: widget.paths.length,
onPageChanged: (i) => setState(() => _index = i),
itemBuilder: (context, index) {
return InteractiveViewer(
child: Center(
child: Image.file(
File(widget.paths[index]),
fit: BoxFit.contain,
errorBuilder: (_, __, ___) => const Icon(
Icons.broken_image_outlined,
color: Color(0xFF4A4D6A),
size: 64,
),
),
),
);
},
),
);
}
}import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../data/data_sources/local_data_sources.dart';


class ManageVideosScreen extends StatefulWidget {
const ManageVideosScreen({super.key});

@override
State<ManageVideosScreen> createState() => _ManageVideosScreenState();
}

class _ManageVideosScreenState extends State<ManageVideosScreen> {
List<String> _paths = [];
bool _loading = true;
final LocalDataSource _localDataSource = sl<LocalDataSource>();

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
final list = await _localDataSource.getVideoPaths();
if (mounted) setState(() { _paths = list; _loading = false; });
}

Future<void> _addVideos() async {
final result = await FilePicker.pickFiles(
type: FileType.video,
allowMultiple: true,
);
if (result == null || result.files.isEmpty) return;

    final current = await _localDataSource.getVideoPaths();
    for (final f in result.files) {
      if (f.path != null && !current.contains(f.path)) {
        current.add(f.path!);
      }
    }
    await _localDataSource.saveVideoPaths(current);
    await _load();
}

Future<void> _delete(String path) async {
final confirmed = await _confirmDelete(context, 'Remove this video?');
if (!confirmed) return;
final current = await _localDataSource.getVideoPaths();
current.remove(path);
await _localDataSource.saveVideoPaths(current);
await _load();
}

Future<bool> _confirmDelete(BuildContext ctx, String message) async {
return await showDialog<bool>(
context: ctx,
builder: (_) => AlertDialog(
backgroundColor: const Color(0xFF1A1C30),
shape:
RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: const Text('Confirm',
style: TextStyle(color: Colors.white, fontSize: 16)),
content: Text(message,
style: const TextStyle(color: Color(0xFFB0B0C8))),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx, false),
child: const Text('Cancel',
style: TextStyle(color: Color(0xFF6A6D8A))),
),
TextButton(
onPressed: () => Navigator.pop(ctx, true),
child: const Text('Remove',
style: TextStyle(color: Color(0xFFC8973A))),
),
],
),
) ??
false;
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF0E0F1C),
appBar: AppBar(
backgroundColor: const Color(0xFF12141F),
foregroundColor: Colors.white,
title: const Text(
'Manage Videos',
style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
),
centerTitle: true,
elevation: 0,
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(height: 1, color: const Color(0xFF1E2035)),
),
actions: [
IconButton(
onPressed: _addVideos,
icon: const Icon(Icons.add_circle_outline, color: Color(0xFFC8973A)),
tooltip: 'Add Videos',
),
],
),
body: _loading
? const Center(
child: CircularProgressIndicator(color: Color(0xFFC8973A)),
)
: _paths.isEmpty
? _buildEmpty()
: _buildList(),
floatingActionButton: FloatingActionButton.extended(
onPressed: _addVideos,
backgroundColor: const Color(0xFFC8973A),
foregroundColor: Colors.black,
icon: const Icon(Icons.video_library_outlined),
label: const Text('Add Videos',
style: TextStyle(fontWeight: FontWeight.bold)),
),
);
}

Widget _buildEmpty() {
return Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.video_library_outlined,
size: 64, color: Colors.white.withValues(alpha: 0.08)),
const SizedBox(height: 16),
const Text('No videos added yet',
style: TextStyle(color: Color(0xFF4A4D6A), fontSize: 15)),
const SizedBox(height: 8),
const Text('Tap the button below to pick videos from your device',
textAlign: TextAlign.center,
style: TextStyle(color: Color(0xFF2E3050), fontSize: 12)),
],
),
);
}

Widget _buildList() {
return ReorderableListView.builder(
padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
itemCount: _paths.length,
proxyDecorator: (Widget child, int index, Animation<double> animation) {
return AnimatedBuilder(
animation: animation,
builder: (BuildContext context, Widget? child) {
final double scale = lerpDouble(1, 1.03, animation.value)!;

            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.5),
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      onReorderStart: (index) {
        HapticFeedback.mediumImpact();
      },
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _paths.removeAt(oldIndex);
          _paths.insert(newIndex, item);
        });
        await _localDataSource.saveVideoPaths(_paths);
      },
      itemBuilder: (context, index) {
        final path = _paths[index];
        final name = path.split('/').last;

        return Container(
          key: ValueKey(path),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141628),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2035), width: 1),
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C30),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: const Color(0xFF2A2D48), width: 1),
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                color: Color(0xFFC8973A),
                size: 26,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Color(0xFFD0D0E8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: _FileSize(path: path),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFF6A3A3A), size: 20),
                  onPressed: () => _delete(path),
                ),
                const Icon(Icons.drag_handle_rounded,
                    color: Color(0xFF2E3050), size: 20),
              ],
            ),
          ),
        );
      },
    );
}
}


class _FileSize extends StatelessWidget {
final String path;
const _FileSize({required this.path});

String _sizeStr() {
try {
final bytes = File(path).lengthSync();
if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
} catch (_) {
return 'Unknown size';
}
}

@override
Widget build(BuildContext context) {
return Text(
_sizeStr(),
style: const TextStyle(color: Color(0xFF4A4D6A), fontSize: 11),
);
}
}import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_products/manage_products_cubit.dart';
import '../../cubit/manage_products/manage_products_state.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';

class EditProductScreen extends StatefulWidget {
final ProductModel? product;

const EditProductScreen({super.key, this.product});

@override
State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
late TextEditingController _nameController;
late TextEditingController _priceController;
final _formKey = GlobalKey<FormState>();

String? _existingFilePath;
String? _newImageBase64;
bool _imageCleared = false;

late bool _showLocalImage;

int? _selectedCategoryId;

@override
void initState() {
super.initState();
_nameController = TextEditingController(text: widget.product?.name ?? '');
_priceController = TextEditingController(
text: widget.product?.price.toString() ?? '');
_selectedCategoryId = widget.product?.categoryId;

    _showLocalImage = widget.product?.showLocalImage ?? true;

    final path = widget.product?.localPath;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('/') && path.length < 500) {
        _existingFilePath = path;
      } else {
        _newImageBase64 = path;
      }
    }
}

@override
void dispose() {
_nameController.dispose();
_priceController.dispose();
super.dispose();
}

Future<void> _pickImage() async {
final XFile? image = await ImagePicker().pickImage(
source: ImageSource.gallery,
imageQuality: 50,
maxWidth: 800,
);
if (image != null) {
final bytes = await image.readAsBytes();
setState(() {
_newImageBase64 = base64Encode(bytes);
_existingFilePath = null;
_imageCleared = false;
});
}
}

bool get _hasImage =>
!_imageCleared && (_newImageBase64 != null || _existingFilePath != null);

void _clearImage() {
setState(() {
_newImageBase64 = null;
_existingFilePath = null;
_imageCleared = true;
});
}

void _handleSave(BuildContext context) {
if (_formKey.currentState!.validate()) {
final name = _nameController.text.trim();
final price = double.tryParse(_priceController.text) ?? 0.0;

      final String? imageToSend = _imageCleared
          ? null
          : (_newImageBase64);

      if (widget.product == null) {
        context.read<ProductsCubit>().createProduct(
          name,
          name,
          price,
          _selectedCategoryId!,
          imageBase64: imageToSend ?? _existingFilePath,
        );
      } else {
        context.read<ProductsCubit>().updateProduct(
          widget.product!.id,
          name,
          price,
          _selectedCategoryId!,
          imageBase64: imageToSend,
          clearImage: _imageCleared,
          showLocalImage: _showLocalImage,
        );
      }
    }
}

@override
Widget build(BuildContext context) {
return MultiBlocProvider(
providers: [
BlocProvider.value(value: sl<ProductsCubit>()),
BlocProvider(
create: (_) => sl<CategoriesCubit>()..fetchCategories()),
],
child: Builder(builder: (innerContext) {
return Scaffold(
backgroundColor: AppTheme.bgBase,
appBar: AppBar(
backgroundColor: AppTheme.bgSurface,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back_ios_new,
color: AppTheme.textPrimary, size: 20),
onPressed: () => Navigator.pop(context),
),
title: Text(
widget.product == null ? 'Add Product' : 'Edit Product',
style: const TextStyle(
color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
),
centerTitle: true,
),
body: BlocListener<ProductsCubit, ProductsState>(
listener: (context, state) {
if (state is ProductActionSuccess) {
Navigator.pop(context);
}
},
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Form(
key: _formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Center(
child: GestureDetector(
onTap: _pickImage,
child: Container(
width: double.infinity,
height: 180,
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: AppTheme.bgBorder),
),
child: _hasImage
? ClipRRect(
borderRadius: BorderRadius.circular(15),
child: Stack(
children: [
Positioned.fill(child: _buildPreview()),
Positioned(
right: 8,
top: 8,
child: IconButton(
onPressed: _clearImage,
icon: const CircleAvatar(
backgroundColor: AppTheme.red,
radius: 18,
child: Icon(Icons.delete_outline,
color: Colors.white, size: 20),
),
),
),
],
),
)
: const Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.add_a_photo_outlined,
size: 40, color: AppTheme.gold),
SizedBox(height: 8),
Text('Tap to select image',
style: TextStyle(
color: AppTheme.textSecondary,
fontSize: 14)),
],
),
),
),
),

                    const SizedBox(height: 16),

                    _buildShowLocalImageToggle(),

                    const SizedBox(height: 32),

                    _buildLabel("Product Name"),
                    _buildReadOnlyField(widget.product?.name ?? '—'),
                    const SizedBox(height: 20),

                    _buildLabel("Price (QR)"),
                    _buildReadOnlyField(
                      widget.product?.price != null
                          ? widget.product!.price.toStringAsFixed(2)
                          : '—',
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Category"),
                    _buildCategoryReadOnly(),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => _handleSave(innerContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          "Save Changes",
                          style: TextStyle(
                              color: AppTheme.textOnGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
}


Widget _buildShowLocalImageToggle() {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: AppTheme.bgBorder),
),
child: Row(
children: [
AnimatedContainer(
duration: const Duration(milliseconds: 200),
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: (_showLocalImage)
? AppTheme.gold.withValues(alpha: 0.15)
: AppTheme.bgCardElevated,
borderRadius: BorderRadius.circular(8),
),
child: AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
child: Icon(
Icons.photo_library_outlined,
key: ValueKey(_showLocalImage),
size: 18,
color: (_showLocalImage)
? AppTheme.gold
: AppTheme.textHint,
),
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Show Local Image',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 2),
AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
child: Text(
key: ValueKey('$_showLocalImage-$_hasImage'),
_showLocalImage
? (_hasImage
? 'Local image will show on main screen'
: 'Ready for local image (to upload)')
: (_hasImage
? 'Network/gradient will show on main screen'
: 'Network/gradient will show on main screen'),
style: const TextStyle(
color: AppTheme.textSecondary,
fontSize: 11,
),
),
),
],
),
),
Switch(
value: _showLocalImage,
onChanged: (val) => setState(() => _showLocalImage = val),
activeColor: AppTheme.gold,
inactiveThumbColor: AppTheme.textHint,
inactiveTrackColor: AppTheme.bgBorder,
),
],
),
);
}


Widget _buildLabel(String text) => Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Text(text,
style: const TextStyle(
color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
);

Widget _buildCategoryReadOnly() {
return BlocBuilder<CategoriesCubit, CategoriesState>(
builder: (context, state) {
String categoryName = '—';
if (state is CategoriesLoaded && _selectedCategoryId != null) {
final match = state.categories
.where((c) => c.id == _selectedCategoryId)
.toList();
if (match.isNotEmpty) categoryName = match.first.name;
}
return _buildReadOnlyField(categoryName);
},
);
}

Widget _buildReadOnlyField(String value) {
return Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: AppTheme.bgBorder),
),
child: Text(value,
style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
);
}

Widget _buildPreview() {
if (_newImageBase64 != null && _newImageBase64!.isNotEmpty) {
try {
final cleanBase64 = _newImageBase64!.trim().split(',').last;
return Image.memory(
base64Decode(cleanBase64),
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) => const Center(
child:
Icon(Icons.broken_image, color: AppTheme.red, size: 40)),
);
} catch (e) {
return const Center(
child: Icon(Icons.broken_image, color: AppTheme.red, size: 40));
}
}

    if (_existingFilePath != null) {
      final file = File(_existingFilePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
              child:
              Icon(Icons.broken_image, color: AppTheme.red, size: 40)),
        );
      }
    }

    return const SizedBox();
}
}import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/service/dependency_injection.dart';
import '../../../../core/service/global_image_settings.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_products/manage_products_cubit.dart';
import '../../cubit/manage_products/manage_products_state.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';
import 'edit_products_screen.dart';

class ManageProductsScreen extends StatelessWidget {
const ManageProductsScreen({super.key});

@override
Widget build(BuildContext context) {
return MultiBlocProvider(
providers: [
BlocProvider(create: (_) => sl<ProductsCubit>()..fetchProducts()),
BlocProvider(create: (_) => sl<CategoriesCubit>()..fetchCategories()),
],
child: const _ManageProductsView(),
);
}
}

class _ManageProductsView extends StatefulWidget {
const _ManageProductsView();

@override
State<_ManageProductsView> createState() => _ManageProductsViewState();
}

class _ManageProductsViewState extends State<_ManageProductsView> {
final TextEditingController _searchController = TextEditingController();
final TextEditingController _categorySearchController = TextEditingController();
String _searchQuery = '';
String _categorySearchQuery = '';

CategoryModel? _selectedCategory;

@override
void dispose() {
_searchController.dispose();
_categorySearchController.dispose();
super.dispose();
}

List<CategoryModel> _filterCategories(List<CategoryModel> categories) {
if (_categorySearchQuery.isEmpty) return categories;
final query = _categorySearchQuery.toLowerCase();
return categories
.where((c) => c.name.toLowerCase().contains(query))
.toList();
}

List<ProductModel> _filterProducts(List<ProductModel> products) {
List<ProductModel> filtered = products;

    if (_selectedCategory != null) {
      filtered = filtered
          .where((p) => p.categoryId == _selectedCategory!.id)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: AppTheme.bgBase,
appBar: AppBar(
backgroundColor: AppTheme.bgSurface,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back_ios_new,
color: AppTheme.textPrimary, size: 20),
onPressed: () {
if (_selectedCategory != null) {
setState(() => _selectedCategory = null);
_searchController.clear();
_searchQuery = '';
} else {
Navigator.pop(context);
}
},
),
actions: [
_GlobalImageToggleButton(),
],
title: Text(
_selectedCategory == null ? 'Manage Products' : _selectedCategory!.name,
style: const TextStyle(
color: AppTheme.textPrimary,
fontWeight: FontWeight.bold,
fontSize: 18),
),
centerTitle: true,
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(height: 1, color: AppTheme.bgBorder),
),
),
body: _selectedCategory == null
? _buildCategoryView()
: _buildProductsView(),
);
}

Widget _buildCategoryView() {
return BlocBuilder<CategoriesCubit, CategoriesState>(
builder: (context, state) {
if (state is CategoriesLoading) {
return const Center(
child: CircularProgressIndicator(color: AppTheme.gold),
);
}

        if (state is CategoriesError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
                const SizedBox(height: 12),
                Text(state.message,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () =>
                      context.read<CategoriesCubit>().fetchCategories(),
                  icon: const Icon(Icons.refresh, color: AppTheme.gold),
                  label: const Text('Retry',
                      style: TextStyle(color: AppTheme.gold)),
                ),
              ],
            ),
          );
        }

        if (state is CategoriesLoaded) {
          final categories = state.categories;
          final filtered = _filterCategories(categories);

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bgBorder),
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      size: 48,
                      color: AppTheme.textHint,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No categories found',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _categorySearchController,
                  onChanged: (value) => setState(() => _categorySearchQuery = value),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: const TextStyle(color: AppTheme.textHint),
                    prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                    suffixIcon: _categorySearchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppTheme.textSecondary, size: 18),
                          onPressed: () {
                            _categorySearchController.clear();
                            setState(() => _categorySearchQuery = '');
                          },
                        )
                        : null,
                    filled: true,
                    fillColor: AppTheme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.bgBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.bgBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                      child: Text(
                        _categorySearchQuery.isNotEmpty
                            ? 'No results for "$_categorySearchQuery"'
                            : 'No categories found',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final category = filtered[index];
                        return _CategoryListItem(
                          category: category,
                          onTap: () {
                            setState(() => _selectedCategory = category);
                          },
                        );
                      },
                    ),
              ),
            ],
          );
        }

        return const SizedBox();
      },
    );
}

Widget _buildProductsView() {
return Column(
children: [
Padding(
padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
child: TextField(
controller: _searchController,
onChanged: (value) => setState(() => _searchQuery = value),
style: const TextStyle(color: AppTheme.textPrimary),
decoration: InputDecoration(
hintText: 'Search ${_selectedCategory?.name ?? "products"}...',
hintStyle: const TextStyle(color: AppTheme.textHint),
prefixIcon:
const Icon(Icons.search, color: AppTheme.textSecondary),
suffixIcon: _searchQuery.isNotEmpty
? IconButton(
icon: const Icon(Icons.clear,
color: AppTheme.textSecondary, size: 18),
onPressed: () {
_searchController.clear();
setState(() => _searchQuery = '');
},
)
: null,
filled: true,
fillColor: AppTheme.bgCard,
contentPadding: const EdgeInsets.symmetric(vertical: 12),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
),
),
),
),

        Expanded(
          child: BlocBuilder<ProductsCubit, ProductsState>(
            builder: (context, state) {
              if (state is ProductsLoading) {
                return const Center(
                    child:
                    CircularProgressIndicator(color: AppTheme.gold));
              }
              if (state is ProductsLoaded) {
                final filtered = _filterProducts(state.products);

                if (state.products.isEmpty) {
                  return const Center(
                    child: Text("No products found",
                        style:
                        TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No results for "$_searchQuery"'
                          : 'No products in this category',
                      style:
                      const TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ProductCard(product: filtered[index]),
                );
              }
              return const Center(
                  child: Text("No products found",
                      style:
                      TextStyle(color: AppTheme.textSecondary)));
            },
          ),
        ),
      ],
    );
}
}


class _CategoryListItem extends StatelessWidget {
final CategoryModel category;
final VoidCallback onTap;

const _CategoryListItem({
required this.category,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: AppTheme.bgBorder),
),
child: Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(16),
onTap: onTap,
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
child: Row(
children: [
if (category.showLocalImage &&
category.localPath != null &&
category.localPath!.isNotEmpty)
ClipRRect(
borderRadius: BorderRadius.circular(10),
child: Image.memory(
base64Decode(category.localPath!),
width: 56,
height: 56,
fit: BoxFit.cover,
),
)
else
Container(
width: 56,
height: 56,
decoration: BoxDecoration(
gradient: AppTheme.goldGradient,
borderRadius: BorderRadius.circular(10),
),
alignment: Alignment.center,
child: const Icon(
Icons.category_rounded,
color: AppTheme.textOnGold,
size: 24,
),
),
const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View products',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
}
}


class _ProductCard extends StatelessWidget {
final ProductModel product;
const _ProductCard({required this.product});

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: AppTheme.bgBorder),
),
child: ListTile(
contentPadding:
const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
onTap: () => Navigator.push(
context,
MaterialPageRoute(
builder: (_) => EditProductScreen(product: product)),
).then((_) {
context.read<ProductsCubit>().fetchProducts();
}),
leading: SizedBox(
width: 56,
height: 56,
child: ClipRRect(
borderRadius: BorderRadius.circular(10),
child: _buildImage(),
),
),
title: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
product.name,
style: const TextStyle(
color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
),
if (product.alternativeName != null && product.alternativeName!.isNotEmpty)Text(
product.alternativeName!,
style: const TextStyle(
color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
),
],
),
subtitle: Text(
"QR ${product.price.toStringAsFixed(2)}",
style: const TextStyle(color: AppTheme.gold),
),
trailing: const Icon(Icons.edit_outlined,
color: AppTheme.textSecondary, size: 20),
),
);
}

Widget _buildImage() {
final path = product.localPath;

    final bool shouldShowLocal = GlobalImageSettings().showLocalImages;

    if (shouldShowLocal && path != null && path.isNotEmpty) {
      if (path.startsWith('/') && path.length < 500) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
      } else {
        try {
          final cleanBase64 = path.trim().split(',').last;
          return Image.memory(
            base64Decode(cleanBase64),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        } catch (e) {
          debugPrint("Manage products image decode failed: $e");
        }
      }
    }

    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
}

Widget _buildPlaceholder() {
return Container(
width: 56,
height: 56,
color: AppTheme.bgCardElevated,
child: const Icon(Icons.fastfood, color: AppTheme.textHint, size: 24),
);
}
}


class _GlobalImageToggleButton extends StatefulWidget {
const _GlobalImageToggleButton();

@override
State<_GlobalImageToggleButton> createState() => _GlobalImageToggleButtonState();
}

class _GlobalImageToggleButtonState extends State<_GlobalImageToggleButton> {
late bool _current;

@override
void initState() {
super.initState();
_current = GlobalImageSettings().showLocalImages;
GlobalImageSettings().addListener(_onSettingChanged);
}

@override
void dispose() {
GlobalImageSettings().removeListener(_onSettingChanged);
super.dispose();
}

void _onSettingChanged() {
if (mounted) setState(() => _current = GlobalImageSettings().showLocalImages);
}

void _openSheet() {
showModalBottomSheet(
context: context,
backgroundColor: Colors.transparent,
builder: (_) => const _GlobalImageBottomSheet(),
);
}

@override
Widget build(BuildContext context) {
return Tooltip(
message: _current ? 'Local images ON' : 'Local images OFF',
child: GestureDetector(
onTap: _openSheet,
child: AnimatedContainer(
duration: const Duration(milliseconds: 250),
margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
decoration: BoxDecoration(
color: _current
? AppTheme.gold.withValues(alpha: 0.15)
: AppTheme.bgCardElevated,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: _current
? AppTheme.gold.withValues(alpha: 0.5)
: AppTheme.bgBorder,
),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
child: Icon(
_current
? Icons.photo_library_rounded
: Icons.photo_library_outlined,
key: ValueKey(_current),
size: 15,
color: _current ? AppTheme.gold : AppTheme.textHint,
),
),
const SizedBox(width: 5),
AnimatedDefaultTextStyle(
duration: const Duration(milliseconds: 200),
style: TextStyle(
fontSize: 11,
fontWeight: FontWeight.bold,
color: _current ? AppTheme.gold : AppTheme.textHint,
),
child: Text(_current ? 'IMG ON' : 'IMG OFF'),
),
],
),
),
),
);
}
}

class _GlobalImageBottomSheet extends StatefulWidget {
const _GlobalImageBottomSheet();

@override
State<_GlobalImageBottomSheet> createState() => _GlobalImageBottomSheetState();
}

class _GlobalImageBottomSheetState extends State<_GlobalImageBottomSheet> {
late bool _value;

@override
void initState() {
super.initState();
_value = GlobalImageSettings().showLocalImages;
GlobalImageSettings().addListener(_sync);
}

@override
void dispose() {
GlobalImageSettings().removeListener(_sync);
super.dispose();
}

void _sync() {
if (mounted) setState(() => _value = GlobalImageSettings().showLocalImages);
}

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
decoration: BoxDecoration(
color: AppTheme.bgSurface,
borderRadius: BorderRadius.circular(24),
border: Border.all(color: AppTheme.bgBorder),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
margin: const EdgeInsets.only(top: 12),
width: 36,
height: 4,
decoration: BoxDecoration(
color: AppTheme.bgBorder,
borderRadius: BorderRadius.circular(2),
),
),
const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppTheme.textOnGold, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Image Display',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Affects all products & categories',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Container(height: 1, color: AppTheme.bgBorder),
          const SizedBox(height: 4),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await GlobalImageSettings().setShowLocalImages(!_value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _value
                        ? AppTheme.gold.withValues(alpha: 0.08)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _value
                          ? AppTheme.gold.withValues(alpha: 0.3)
                          : AppTheme.bgBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _value
                              ? AppTheme.gold.withValues(alpha: 0.15)
                              : AppTheme.bgCardElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _value
                              ? Icons.photo_library_rounded
                              : Icons.hide_image_outlined,
                          size: 20,
                          color: _value ? AppTheme.gold : AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _value
                                  ? 'Showing local images'
                                  : 'Showing network / gradient',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _value
                                  ? 'All products display their uploaded local image'
                                  : 'All products fall back to network image or gradient',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _value,
                        onChanged: (val) async {
                          await GlobalImageSettings().setShowLocalImages(val);
                        },
                        activeColor: AppTheme.gold,
                        inactiveThumbColor: AppTheme.textHint,
                        inactiveTrackColor: AppTheme.bgBorder,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: AppTheme.textHint),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Individual product settings still apply when this is ON.',
                    style: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],// lib/utils/app_dialogs.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../utils/app_enum.dart';

/// A custom, animated, and reusable dialog for showing success or failure states.
/// It supports both a single primary action button and an optional secondary button.
///
/// --- ONE BUTTON EXAMPLE ---
/// showAppDialog(
///   context: context,
///   isSuccess: true,
///   title: 'Success!',
///   message: 'Your action was completed.',
///   confirmButtonText: 'Done',
///   onConfirmPressed: () => print('Done pressed'),
/// );
///
/// --- TWO BUTTON EXAMPLE ---
/// showAppDialog(
///   context: context,
///   isSuccess: false,
///   title: 'Are you sure?',
///   message: 'This action cannot be undone.',
///   confirmButtonText: 'Confirm',
///   onConfirmPressed: () => print('Confirmed'),
///   cancelButtonText: 'Cancel',
///   onCancelPressed: () => print('Cancelled'),
/// );
///
Future<void> showAppDialog({
required BuildContext context,
required AppDialogType type,
required String title,
required String message,
Widget? customContent,
String confirmButtonText = "OK",
required VoidCallback onConfirmPressed,
String? cancelButtonText,
VoidCallback? onCancelPressed,
}) {
return showGeneralDialog(
context: context,
barrierDismissible: false,
barrierLabel: 'App Dialog',
transitionDuration: const Duration(milliseconds: 300),
transitionBuilder: (context, anim1, anim2, child) {
return Transform.scale(
scale: anim1.value,
child: child,
);
},
pageBuilder: (context, anim1, anim2) {
return _AppDialogContent(
type: type,
title: title,
customContent: customContent,
message: message,
confirmButtonText: confirmButtonText,
onConfirmPressed: onConfirmPressed,
cancelButtonText: cancelButtonText,
onCancelPressed: onCancelPressed,
);
},
);
}

/// The internal widget that builds the dialog's content.
class _AppDialogContent extends StatefulWidget {
final AppDialogType type;
final String title;
final String message;
final String confirmButtonText;
final VoidCallback onConfirmPressed;
final String? cancelButtonText;
final VoidCallback? onCancelPressed;
final Widget? customContent;

const _AppDialogContent({
required this.type,
required this.title,
required this.message,
required this.confirmButtonText,
required this.onConfirmPressed,
this.cancelButtonText,
this.customContent,
this.onCancelPressed,
});

@override
State<_AppDialogContent> createState() => _AppDialogContentState();
}

class _AppDialogContentState extends State<_AppDialogContent>
with SingleTickerProviderStateMixin {
late final AnimationController _lottieController;

@override
void initState() {
super.initState();
_lottieController = AnimationController(
vsync: this,
duration: const Duration(seconds: 2),
);
_lottieController.forward();
}

@override
void dispose() {
_lottieController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
late final String animationAsset;
late final Color primaryColor;

    switch (widget.type) {
      case AppDialogType.success:
        animationAsset = 'assets/animations/successAnimation.json';
        primaryColor = Colors.green.shade600;
        break;

      case AppDialogType.error:
        animationAsset = 'assets/animations/failedAnimation.json';
        primaryColor = Colors.red.shade600;
        break;

      case AppDialogType.confirmation:
        animationAsset = 'assets/animations/infoAnimation.json';
        primaryColor = Colors.blue.shade600;
        break;
    }

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              animationAsset,
              controller: _lottieController,
              height: 120,
              width: 120,
              repeat: false,
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            // Text(
            //   widget.message,
            //   textAlign: TextAlign.center,
            //   style: TextStyle(
            //     fontSize: 16,
            //     color: Colors.grey.shade600,
            //   ),
            // ),
            if (widget.customContent != null)
              widget.customContent!
            else
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),

            const SizedBox(height: 24),

            // --- MODIFIED: Replaced single button with a Row for two buttons ---
            Row(
              children: [
                // --- NEW: Optional Cancel Button ---
                if (widget.cancelButtonText != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        widget.onCancelPressed?.call(); // Call optional callback
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.cancelButtonText!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),

                // Add space between buttons if both are present
                if (widget.cancelButtonText != null)
                  const SizedBox(width: 12),

                // Primary Confirm Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      widget.onConfirmPressed();   // Call callback
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.confirmButtonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
}
}import 'package:flutter/material.dart';

class AppDropdown<T> extends StatefulWidget {
final String labelText;
final String hintText;
final List<T> items;
final T? selectedItem;
final String Function(T) itemToString;
final ValueChanged<T> onChanged;
final double height;
final double? maxDropdownHeight;

const AppDropdown({
super.key,
required this.items,
required this.labelText,
required this.hintText,
required this.itemToString,
required this.onChanged,
this.selectedItem,
this.maxDropdownHeight,
this.height = 50,
});

@override
State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
final LayerLink _layerLink = LayerLink();
OverlayEntry? _overlayEntry;
bool _isOpen = false;

void _toggleDropdown() {
if (_isOpen) {
_removeDropdown();
} else {
_showDropdown();
}
}


void _showDropdown() {
FocusManager.instance.primaryFocus
?.unfocus();
final overlay = Overlay.of(context);
final renderBox = context.findRenderObject() as RenderBox;
final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _removeDropdown,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + renderBox.size.height,
              width: renderBox.size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, widget.height),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: widget.maxDropdownHeight ?? 200,
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: widget.items.map((item) {
                        return Column(
                          children: [
                            ListTile(
                              title: Text(widget.itemToString(item)),
                              onTap: () {
                                widget.onChanged(item);
                                _removeDropdown();
                              },
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Theme.of(context).dividerColor,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
}

void _removeDropdown() {
_overlayEntry?.remove();
_overlayEntry = null;
if (mounted) {
setState(() => _isOpen = false);
}
}


@override
void dispose() {
_overlayEntry?.remove();
_overlayEntry = null;
super.dispose();
}


@override
Widget build(BuildContext context) {
return CompositedTransformTarget(
link: _layerLink,
child: GestureDetector(
onTap: _toggleDropdown,
behavior: HitTestBehavior.translucent,
child: InputDecorator(
isEmpty: widget.selectedItem == null,
isFocused: _isOpen,
decoration: InputDecoration(
labelText: widget.labelText,
hintText: widget.hintText,
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
widget.selectedItem != null
? widget.itemToString(widget.selectedItem as T)
: '',
style: TextStyle(
color: widget.selectedItem != null
? Colors.black
: Theme.of(context).hintColor,
fontWeight: widget.selectedItem != null
? FontWeight.w700
: FontWeight.w400,
fontSize: 16,
),
),
Icon(Icons.keyboard_arrow_down,size: 24,color: Colors.black,),
],
),
),
),
);
}

}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
final TextEditingController? controller;
final String? Function(String?)? validator;
final String? labelText;
final bool? obscureText;
final int? maxLength;
final TextInputAction? textInputAction;
final TextInputType? keyboardType;
final List<TextInputFormatter>? inputFormatters;

const AppTextField({
super.key,
this.controller,
this.validator,
this.labelText,
this.textInputAction,
this.keyboardType,
this.inputFormatters,
this.obscureText = false,
this.maxLength,
});

@override
Widget build(BuildContext context) {
return InkWell(
child: TextFormField(
controller: controller,
textInputAction: textInputAction,
maxLength: maxLength,
buildCounter: (
BuildContext context, {
required int currentLength,
required int? maxLength,
required bool isFocused,
}) {
return null;
},
decoration: InputDecoration(
labelText: labelText,
labelStyle: TextStyle(
color: Colors.black,
fontSize: 14,
fontWeight: FontWeight.w400,
),
fillColor: Colors.black.withValues(alpha: .5),
filled: true,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
      ),
    );
}
}
import 'package:flutter/material.dart';
import 'dart:math' as math;


class CubeGridBounceLoader extends StatefulWidget {
const CubeGridBounceLoader({
super.key,
this.gridSize = 4,
this.cubeSize = 10.0,
this.duration = const Duration(milliseconds: 1500),
this.primaryColor,
});

final int gridSize;
final double cubeSize;
final Duration duration;
final Color? primaryColor;

@override
State<CubeGridBounceLoader> createState() => _CubeGridBounceLoaderState();
}

class _CubeGridBounceLoaderState extends State<CubeGridBounceLoader>
with SingleTickerProviderStateMixin {
late AnimationController _controller;
Color? primaryColor;
@override
void initState() {
super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

Widget _buildCube(int index) {
final i = index ~/ widget.gridSize;
final j = index % widget.gridSize;

    final positionFactor = (i + j) / (2 * (widget.gridSize - 1));
    final delay = positionFactor * 0.5;

    final cubeInterval = Interval(
      delay,
      delay + 0.5,
      curve: Curves.easeInOutSine,
    );

    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: cubeInterval,
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final bounceValue = math.sin(animation.value * math.pi);

        final yOffset = bounceValue * -10.0;

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Container(
            width: widget.cubeSize,
            height: widget.cubeSize,
            decoration: BoxDecoration(
              color: primaryColor!.withValues(alpha: 0.3 + bounceValue * 0.7),
              borderRadius: BorderRadius.circular(2.0),
              boxShadow: [
                BoxShadow(
                  color: primaryColor!.withValues(alpha : bounceValue * 0.6),
                  blurRadius: 5.0,
                ),
              ],
            ),
          ),
        );
      },
    );
}

@override
Widget build(BuildContext context) {
final totalSpacing = widget.gridSize - 1;
final totalSize = (widget.gridSize * widget.cubeSize) + (totalSpacing * 4.0);
primaryColor = widget.primaryColor;
return Center(
child: SizedBox(
width: totalSize,
height: totalSize,
child: GridView.builder(
physics: const NeverScrollableScrollPhysics(),
itemCount: widget.gridSize * widget.gridSize,
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: widget.gridSize,
mainAxisSpacing: 4.0,
crossAxisSpacing: 4.0,
childAspectRatio: 1.0,
),
itemBuilder: (context, index) {
return _buildCube(index);
},
),
),
);
}
}import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../utils/app_theme.dart';
import '../../data/models/pos_models.dart';

/// Call this from anywhere:
///   showProductImagePopup(context, product);
void showProductImagePopup(BuildContext context, ProductModel product) {
showDialog(
context: context,
barrierColor: Colors.transparent,
barrierDismissible: false,
builder: (_) => _ProductImageDialog(product: product),
);
}

class _ProductImageDialog extends StatelessWidget {
final ProductModel product;
const _ProductImageDialog({required this.product});

@override
Widget build(BuildContext context) {
final screenH = MediaQuery.of(context).size.height;
final screenW = MediaQuery.of(context).size.width;
final imageMaxH = screenH * 0.55;
final imageW = screenW - 40.w;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),

          Center(
            child: GestureDetector(
              onTap: () {},
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: imageW,
                            maxHeight: imageMaxH,
                          ),
                          child: _buildImage(imageW, imageMaxH),
                        ),
                      ),

                      SizedBox(height: 14.h),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: 18.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                              AppTheme.bgBorder.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'QR ${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppTheme.gold,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
}

Widget _buildImage(double maxW, double maxH) {
final path = product.localPath;
final bool shouldShowLocal = product.showLocalImage;

    if (shouldShowLocal && path != null && path.isNotEmpty) {
      if (path.startsWith('/') && path.length < 500) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: maxW,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _networkFallback(maxW, maxH),
          );
        }
      } else {
        try {
          final clean = path.trim().split(',').last;
          return Image.memory(
            base64Decode(clean),
            width: maxW,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _networkFallback(maxW, maxH),
          );
        } catch (_) {}
      }
    }

    return _networkFallback(maxW, maxH);
}

Widget _networkFallback(double maxW, double maxH) {
if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
return Image.network(
product.imageUrl!,
width: maxW,
fit: BoxFit.contain,
loadingBuilder: (_, child, progress) => progress == null
? child
: SizedBox(
width: maxW,
height: maxH * 0.5,
child: const Center(
child: CircularProgressIndicator(color: AppTheme.gold)),
),
errorBuilder: (_, __, ___) => _placeholder(maxW, maxH),
);
}
return _placeholder(maxW, maxH);
}

Widget _placeholder(double maxW, double maxH) {
return Container(
width: maxW,
height: maxH * 0.5,
decoration: BoxDecoration(
color: AppTheme.bgCard,
borderRadius: BorderRadius.circular(20),
),
child: const Center(
child: Icon(Icons.fastfood_rounded,
color: AppTheme.textHint, size: 52),
),
);
}
}

class AppConstants {
static const bool useMockData = true;
static const String appName = 'DPOS';
static String? accessToken;
static String? refreshToken;
static int? userId;
static const int connectionTimeout = 60;
}
// ignore_for_file: constant_identifier_names

enum ButtonType{Primary, Secondary, Outline}
enum PaymentMethod{Full, Advance}
enum AppDialogType {
success,
error,
confirmation,
}
class AppStrings{
static const String somethingWentWrong = "Something went wrong. Please try again";
static const String unAuthorizedDes = "Unauthorized. Please login again.";
}import 'package:flutter/material.dart';

class AppStyling {
static const TextStyle boldTextSize16 = TextStyle(
fontWeight: FontWeight.w700,
fontSize: 16,
);
static const TextStyle boldTextSize18 = TextStyle(
fontWeight: FontWeight.w700,
fontSize: 18,
);
static const TextStyle boldTextSize20 = TextStyle(
fontWeight: FontWeight.w700,
fontSize: 20,
);
static const TextStyle boldTextSize30 = TextStyle(
fontWeight: FontWeight.w600,
fontSize: 30,
);
static const TextStyle text400Size26 = TextStyle(
fontWeight: FontWeight.w400,
fontSize: 26,
);
static const TextStyle text500Size15 = TextStyle(
fontWeight: FontWeight.w500,
fontSize: 15,
);
}
import 'package:flutter/material.dart';

class AppTheme {
// === DARK BACKGROUND PALETTE ===
static const Color bgBase = Color(0xFF0D0F1A);
static const Color bgSurface = Color(0xFF151722);
static const Color bgCard = Color(0xFF1C1E2C);
static const Color bgCardElevated = Color(0xFF242638);
static const Color bgBorder = Color(0xFF2E3148);

// === BRAND PALETTE ===
static const Color gold = Color(0xFFC8973A);
static const Color goldLight = Color(0xFFE8C870);
static const Color goldDim = Color(0xFF8C6828);
static const Color green = Color(0xFF6DB352);
static const Color greenDim = Color(0xFF3E6630);
static const Color red = Color(0xFFE85A4F);
static const Color blue = Color(0xFF7B9FD9);

// === TEXT PALETTE ===
static const Color textPrimary = Color(0xFFF0EEE8);
static const Color textSecondary = Color(0xFF9B9BA8);
static const Color textHint = Color(0xFF5A5C6E);
static const Color textOnGold = Color(0xFF1A0E00);

// === GRADIENTS ===
static const LinearGradient goldGradient = LinearGradient(
colors: [Color(0xFFC8973A), Color(0xFFE8C870)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
);

static const LinearGradient goldGradientVertical = LinearGradient(
colors: [Color(0xFFE8C870), Color(0xFFC8973A)],
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
);

static const LinearGradient bgGradient = LinearGradient(
colors: [Color(0xFF0D0F1A), Color(0xFF13152A)],
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
);

static const LinearGradient cardGradient = LinearGradient(
colors: [Color(0xFF1C1E2C), Color(0xFF242638)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
);

static const LinearGradient greenGradient = LinearGradient(
colors: [Color(0xFF6DB352), Color(0xFF90C068)],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
);

// === THEME DATA ===
static ThemeData get dark {
return ThemeData(
brightness: Brightness.dark,
scaffoldBackgroundColor: bgBase,
primaryColor: gold,
colorScheme: const ColorScheme.dark(
primary: gold,
secondary: green,
surface: bgCard,
error: red,
),
appBarTheme: const AppBarTheme(
backgroundColor: bgSurface,
elevation: 0,
centerTitle: true,
iconTheme: IconThemeData(color: textPrimary),
titleTextStyle: TextStyle(
color: textPrimary,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
dividerColor: bgBorder,
cardColor: bgCard,
);
}


static InputDecoration inputDecoration({required String hint, IconData? prefixIcon}) {
return InputDecoration(
hintText: hint,
hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
filled: true,
fillColor: AppTheme.bgCardElevated,
prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.gold, size: 20) : null,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.bgBorder),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
),
errorBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.red),
),
);
}
}
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

      ),
    );
}
}import 'package:flutter/material.dart';

class SplashView extends StatelessWidget {
const SplashView({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
body: Container(),
);
}
}
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