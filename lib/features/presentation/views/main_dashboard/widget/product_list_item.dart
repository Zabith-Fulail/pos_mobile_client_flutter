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
}