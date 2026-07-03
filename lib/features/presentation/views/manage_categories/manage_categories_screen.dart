import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';
import 'edit_category_screen.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CategoriesCubit>()..fetchCategories(),
      child: const _ManageCategoriesView(),
    );
  }
}

class _ManageCategoriesView extends StatefulWidget {
  const _ManageCategoriesView();

  @override
  State<_ManageCategoriesView> createState() => _ManageCategoriesViewState();
}

class _ManageCategoriesViewState extends State<_ManageCategoriesView>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }



  void _showEditDialog(BuildContext context, CategoryModel cat) {
    _showCategoryDialog(
      context,
      title: 'Edit Category',
      initialValue: cat.name,
      initialImageBase64: cat.localPath,
      onConfirm: (name, image) {
        context.read<CategoriesCubit>().updateCategory(cat.id, name, imageBase64: image);
      },
    );
  }

  void _showCategoryDialog(
      BuildContext outerContext, {
        required String title,
        String initialValue = '',
        String? initialImageBase64,
        required Function(String name, String? imageBase64) onConfirm,
      }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    String? selectedImageBase64 = initialImageBase64;

    showDialog(
      context: outerContext,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          color: AppTheme.textOnGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  StatefulBuilder(
                    builder: (ctx, setState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Image',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.bgBorder),
                            color: AppTheme.bgCardElevated,
                          ),
                          child: selectedImageBase64 != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.memory(
                                  base64Decode(selectedImageBase64!),
                                  fit: BoxFit.cover,
                                ),
                              )
                              : GestureDetector(
                                onTap: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (image != null) {
                                    final bytes = await image.readAsBytes();
                                    final base64Image = base64Encode(bytes);
                                    setState(() {
                                      selectedImageBase64 = base64Image;
                                    });
                                  }
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_rounded,
                                        color: AppTheme.gold, size: 40),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap to select image',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                        if (selectedImageBase64 != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() => selectedImageBase64 = null);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.red.withValues(alpha: 0.15),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.delete_outline, color: AppTheme.red),
                              label: const Text(
                                'Remove image',
                                style: TextStyle(color: AppTheme.red),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.bgCardElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.bgBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.bgBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: AppTheme.gold, width: 1.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.drive_file_rename_outline,
                        color: AppTheme.gold,
                        size: 20,
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.bgBorder),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(ctx);
                                onConfirm(controller.text, selectedImageBase64);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                color: AppTheme.textOnGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Category',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remove "${cat.name}" from the menu?\nThis cannot be undone.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.bgBorder),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<CategoriesCubit>().deleteCategory(cat.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
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
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Manage Categories',
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
      body: BlocConsumer<CategoriesCubit, CategoriesState>(
        listener: (context, state) {
          if (state is CategoryActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(state.message),
                  ],
                ),
                backgroundColor: AppTheme.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
          } else if (state is CategoryActionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
        builder: (context, state) => _buildBody(context, state),
      ),
    );
  }


  Widget _buildBody(BuildContext context, CategoriesState state) {
    List<CategoryModel> categories = [];
    bool isActionLoading = false;

    if (state is CategoriesLoaded) categories = state.categories;
    if (state is CategoryActionLoading) {
      categories = state.categories;
      isActionLoading = true;
    }
    if (state is CategoryActionSuccess) categories = state.categories;
    if (state is CategoryActionError) categories = state.categories;

    if (state is CategoriesLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppTheme.gold,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading categories...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state is CategoriesError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
            const SizedBox(height: 12),
            Text(
              state.message,
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () =>
                  context.read<CategoriesCubit>().fetchCategories(),
              icon: const Icon(Icons.refresh, color: AppTheme.gold),
              label: const Text('Retry',
                  style: TextStyle(color: AppTheme.gold)),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        categories.isEmpty
            ? _buildEmptyState(context)
            : _buildCategoryList(context, categories),

        if (isActionLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: AppTheme.gold,
              backgroundColor: AppTheme.bgBorder,
              minHeight: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bgBorder),
            ),
            child: const Icon(
              Icons.category_outlined,
              size: 48,
              color: AppTheme.textHint,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No categories yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "New Category" below to get started.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(
      BuildContext context, List<CategoryModel> categories) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _CategoryCard(
          category: cat,
          index: index,
          onEdit: () => _showEditDialog(context, cat),
          onDelete: () => _showDeleteDialog(context, cat),
        );
      },
    );
  }
}


class _CategoryCard extends StatefulWidget {
  final CategoryModel category;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (widget.index * 60)),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.bgBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditCategoryScreen(category: widget.category),
                  ),
                ).then((_){
                  context.read<CategoriesCubit>().fetchCategories();
                });
              },
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    if (widget.category.showLocalImage && widget.category.localPath != null && widget.category.localPath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(widget.category.localPath!),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.category_rounded,
                          color: AppTheme.textOnGold,
                          size: 24,
                        ),
                      ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Text(
                        widget.category.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    _ActionIconBtn(
                      icon: Icons.edit_rounded,
                      color: AppTheme.blue,
                      onTap: widget.onEdit,
                    ),
                    const SizedBox(width: 8),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}