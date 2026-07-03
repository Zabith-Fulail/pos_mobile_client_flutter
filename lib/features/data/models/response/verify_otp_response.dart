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
