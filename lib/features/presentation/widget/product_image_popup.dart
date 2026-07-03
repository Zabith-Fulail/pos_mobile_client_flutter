import 'dart:convert';
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