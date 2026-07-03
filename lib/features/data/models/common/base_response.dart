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
