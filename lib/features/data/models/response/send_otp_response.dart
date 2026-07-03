// To parse this JSON data, do
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
