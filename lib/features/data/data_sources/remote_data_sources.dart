import 'dart:convert';
import 'dart:developer';

import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_helper.dart';
import '../models/common/base_response.dart';
import '../models/request/extracted_order_model.dart';
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

  Future<ExtractedOrderModel> extractOrder(String transcript);

}

class RemoteDataSourceImpl implements RemoteDataSource {
  final ApiHelper apiHelper;

  RemoteDataSourceImpl({required this.apiHelper});

  static const _model = 'gemini-3.1-flash-lite';
  static String get _geminiEndpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=${Env.geminiApiKey}';

  static const _systemPrompt = '''
You convert a spoken restaurant order into structured JSON.
Return ONLY valid JSON matching exactly:
{
  "items": [
    {
      "name": "string",
      "quantity": integer,
      "modifiers": [
        { "name": "string", "negated": boolean }
      ]
    }
  ]
}
Rules:
- negated=true means customer does NOT want it (e.g. "no pickles").
- Default quantity to 1 if not stated.
''';


  @override
  Future<ExtractedOrderModel> extractOrder(String transcript) async {
    try {
      final response = await apiHelper.post(
        _geminiEndpoint,
        data: {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': '$_systemPrompt\n\nCustomer said: "$transcript"'}
              ],
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
          },
        },
        options: Options(
          extra: {
            'bypass_auth': true,
          },
        ),
      );

      final Map<String, dynamic> responseMap = response is String
          ? jsonDecode(response) as Map<String, dynamic>
          : response as Map<String, dynamic>;

      final candidates = responseMap['candidates'] as List;
      if (candidates.isEmpty) {
        throw Exception("Gemini returned an empty candidate list.");
      }

      final firstCandidate = candidates[0] as Map<String, dynamic>;
      final content = firstCandidate['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List;
      final textContent = parts[0]['text'] as String;

      final Map<String, dynamic> parsedJson = jsonDecode(textContent) as Map<String, dynamic>;

      return ExtractedOrderModel.fromJson(parsedJson);
    } catch (e, stackTrace) {
      log("=== GEMINI PARSING ERROR ===");
      log("Error: $e");
      log("StackTrace: $stackTrace");
      rethrow;
    }
  }

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