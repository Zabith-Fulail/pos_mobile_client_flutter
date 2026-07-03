import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_products/manage_products_cubit.dart';
import '../../cubit/manage_products/manage_products_state.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';

class EditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const EditProductScreen({super.key, this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  final _formKey = GlobalKey<FormState>();

  String? _existingFilePath;
  String? _newImageBase64;
  bool _imageCleared = false;

  late bool _showLocalImage;

  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
        text: widget.product?.price.toString() ?? '');
    _selectedCategoryId = widget.product?.categoryId;

    _showLocalImage = widget.product?.showLocalImage ?? true;

    final path = widget.product?.localPath;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('/') && path.length < 500) {
        _existingFilePath = path;
      } else {
        _newImageBase64 = path;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
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
        _newImageBase64 = base64Encode(bytes);
        _existingFilePath = null;
        _imageCleared = false;
      });
    }
  }

  bool get _hasImage =>
      !_imageCleared && (_newImageBase64 != null || _existingFilePath != null);

  void _clearImage() {
    setState(() {
      _newImageBase64 = null;
      _existingFilePath = null;
      _imageCleared = true;
    });
  }

  void _handleSave(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final price = double.tryParse(_priceController.text) ?? 0.0;

      final String? imageToSend = _imageCleared
          ? null
          : (_newImageBase64);

      if (widget.product == null) {
        context.read<ProductsCubit>().createProduct(
          name,
          name,
          price,
          _selectedCategoryId!,
          imageBase64: imageToSend ?? _existingFilePath,
        );
      } else {
        context.read<ProductsCubit>().updateProduct(
          widget.product!.id,
          name,
          price,
          _selectedCategoryId!,
          imageBase64: imageToSend,
          clearImage: _imageCleared,
          showLocalImage: _showLocalImage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<ProductsCubit>()),
        BlocProvider(
            create: (_) => sl<CategoriesCubit>()..fetchCategories()),
      ],
      child: Builder(builder: (innerContext) {
        return Scaffold(
          backgroundColor: AppTheme.bgBase,
          appBar: AppBar(
            backgroundColor: AppTheme.bgSurface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppTheme.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.product == null ? 'Add Product' : 'Edit Product',
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: BlocListener<ProductsCubit, ProductsState>(
            listener: (context, state) {
              if (state is ProductActionSuccess) {
                Navigator.pop(context);
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.bgBorder),
                          ),
                          child: _hasImage
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              children: [
                                Positioned.fill(child: _buildPreview()),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: IconButton(
                                    onPressed: _clearImage,
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
                              Icon(Icons.add_a_photo_outlined,
                                  size: 40, color: AppTheme.gold),
                              SizedBox(height: 8),
                              Text('Tap to select image',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildShowLocalImageToggle(),

                    const SizedBox(height: 32),

                    _buildLabel("Product Name"),
                    _buildReadOnlyField(widget.product?.name ?? '—'),
                    const SizedBox(height: 20),

                    _buildLabel("Price (QR)"),
                    _buildReadOnlyField(
                      widget.product?.price != null
                          ? widget.product!.price.toStringAsFixed(2)
                          : '—',
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Category"),
                    _buildCategoryReadOnly(),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => _handleSave(innerContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          "Save Changes",
                          style: TextStyle(
                              color: AppTheme.textOnGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }


  Widget _buildShowLocalImageToggle() {
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
                    key: ValueKey('$_showLocalImage-$_hasImage'),
                    _showLocalImage
                        ? (_hasImage
                            ? 'Local image will show on main screen'
                            : 'Ready for local image (to upload)')
                        : (_hasImage
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
            onChanged: (val) => setState(() => _showLocalImage = val),
            activeColor: AppTheme.gold,
            inactiveThumbColor: AppTheme.textHint,
            inactiveTrackColor: AppTheme.bgBorder,
          ),
        ],
      ),
    );
  }


  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
  );

  Widget _buildCategoryReadOnly() {
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        String categoryName = '—';
        if (state is CategoriesLoaded && _selectedCategoryId != null) {
          final match = state.categories
              .where((c) => c.id == _selectedCategoryId)
              .toList();
          if (match.isNotEmpty) categoryName = match.first.name;
        }
        return _buildReadOnlyField(categoryName);
      },
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: Text(value,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
    );
  }

  Widget _buildPreview() {
    if (_newImageBase64 != null && _newImageBase64!.isNotEmpty) {
      try {
        final cleanBase64 = _newImageBase64!.trim().split(',').last;
        return Image.memory(
          base64Decode(cleanBase64),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
              child:
              Icon(Icons.broken_image, color: AppTheme.red, size: 40)),
        );
      } catch (e) {
        return const Center(
            child: Icon(Icons.broken_image, color: AppTheme.red, size: 40));
      }
    }

    if (_existingFilePath != null) {
      final file = File(_existingFilePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
              child:
              Icon(Icons.broken_image, color: AppTheme.red, size: 40)),
        );
      }
    }

    return const SizedBox();
  }
}