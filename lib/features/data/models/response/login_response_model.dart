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
