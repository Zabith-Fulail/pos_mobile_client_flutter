// lib/utils/app_dialogs.dart

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
}