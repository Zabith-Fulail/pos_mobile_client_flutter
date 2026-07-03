class LoginRequest {
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
}