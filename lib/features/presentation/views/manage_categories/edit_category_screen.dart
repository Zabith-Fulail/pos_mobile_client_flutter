import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';

class EditCategoryScreen extends StatefulWidget {
  final CategoryModel category;

  const EditCategoryScreen({super.key, required this.category});

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  String? _selectedImageBase64;
  bool _showLocalImage = true;

  @override
  void initState() {
    super.initState();
    _selectedImageBase64 = widget.category.localPath;
    _showLocalImage = widget.category.showLocalImage;
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CategoriesCubit>(),
      child: Builder(
        builder: (innerContext) {
          return Scaffold(
            backgroundColor: AppTheme.bgBase,
            appBar: AppBar(
              backgroundColor: AppTheme.bgSurface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Edit Category',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppTheme.bgBorder),
              ),
            ),
            body: BlocListener<CategoriesCubit, CategoriesState>(
              listener: (context, state) {
                if (state is CategoryActionSuccess) {
                  Navigator.pop(context);
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category Image',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.bgBorder),
                          color: AppTheme.bgCardElevated,
                        ),
                        child: _selectedImageBase64 != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                  child: _buildImagePreview()),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.45),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit,
                                          color: Colors.white,
                                          size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tap to change image',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: IconButton(
                                  onPressed: () => setState(
                                          () => _selectedImageBase64 = null),
                                  icon: const CircleAvatar(
                                    backgroundColor: AppTheme.red,
                                    radius: 18,
                                    child: Icon(Icons.delete_outline,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_rounded,
                                color: AppTheme.gold, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Tap to select image',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildShowLocalImageToggle(),

                    const SizedBox(height: 32),

                    const Text(
                      'Category Details',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      icon: Icons.drive_file_rename_outline,
                      label: 'Category Name',
                      value: widget.category.name,
                    ),
                    const SizedBox(height: 40),

                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          innerContext.read<CategoriesCubit>().updateCategory(
                            widget.category.id,
                            widget.category.name,
                            imageBase64: _selectedImageBase64,
                            showLocalImage: _showLocalImage,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: AppTheme.textOnGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildShowLocalImageToggle() {
    final hasLocalImage =
        _selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_showLocalImage)
                  ? AppTheme.gold.withValues(alpha: 0.15)
                  : AppTheme.bgCardElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.photo_library_outlined,
                key: ValueKey(_showLocalImage),
                size: 18,
                color: (_showLocalImage)
                    ? AppTheme.gold
                    : AppTheme.textHint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Show Local Image',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    key: ValueKey('$_showLocalImage-$hasLocalImage'),
                    _showLocalImage
                        ? (hasLocalImage
                            ? 'Local image will show on main screen'
                            : 'Ready for local image (to upload)')
                        : (hasLocalImage
                            ? 'Network/gradient will show on main screen'
                            : 'Network/gradient will show on main screen'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _showLocalImage,
            onChanged: (val) {
              setState(() {
                _showLocalImage = val;
              });
            },
            activeColor: AppTheme.gold,
            inactiveThumbColor: AppTheme.textHint,
            inactiveTrackColor: AppTheme.bgBorder,
          ),
        ],
      ),
    );
  }


  Widget _buildReadOnlyField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.bgCardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gold, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImageBase64 == null || _selectedImageBase64!.isEmpty) {
      return const SizedBox();
    }

    if (_selectedImageBase64!.startsWith('/')) {
      final file = File(_selectedImageBase64!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    try {
      final cleanBase64 = _selectedImageBase64!.trim();
      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child:
          Icon(Icons.broken_image, color: AppTheme.red, size: 40),
        ),
      );
    } catch (e) {
      return const Center(
        child:
        Icon(Icons.broken_image, color: AppTheme.red, size: 40),
      );
    }
  }
}