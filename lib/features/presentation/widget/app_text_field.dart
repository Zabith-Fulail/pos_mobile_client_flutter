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
