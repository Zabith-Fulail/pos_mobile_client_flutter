import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/service/dependency_injection.dart';
import '../../../../core/service/global_image_settings.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/manage_products/manage_products_cubit.dart';
import '../../cubit/manage_products/manage_products_state.dart';
import '../../cubit/manage_categories/manage_categories_cubit.dart';
import '../../cubit/manage_categories/manage_categories_state.dart';
import 'edit_products_screen.dart';

class ManageProductsScreen extends StatelessWidget {
  const ManageProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ProductsCubit>()..fetchProducts()),
        BlocProvider(create: (_) => sl<CategoriesCubit>()..fetchCategories()),
      ],
      child: const _ManageProductsView(),
    );
  }
}

class _ManageProductsView extends StatefulWidget {
  const _ManageProductsView();

  @override
  State<_ManageProductsView> createState() => _ManageProductsViewState();
}

class _ManageProductsViewState extends State<_ManageProductsView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categorySearchController = TextEditingController();
  String _searchQuery = '';
  String _categorySearchQuery = '';
  
  CategoryModel? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  List<CategoryModel> _filterCategories(List<CategoryModel> categories) {
    if (_categorySearchQuery.isEmpty) return categories;
    final query = _categorySearchQuery.toLowerCase();
    return categories
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    List<ProductModel> filtered = products;

    if (_selectedCategory != null) {
      filtered = filtered
          .where((p) => p.categoryId == _selectedCategory!.id)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
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
          onPressed: () {
            if (_selectedCategory != null) {
              setState(() => _selectedCategory = null);
              _searchController.clear();
              _searchQuery = '';
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          _GlobalImageToggleButton(),
        ],
        title: Text(
          _selectedCategory == null ? 'Manage Products' : _selectedCategory!.name,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.bgBorder),
        ),
      ),
      body: _selectedCategory == null
          ? _buildCategoryView()
          : _buildProductsView(),
    );
  }

  Widget _buildCategoryView() {
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        if (state is CategoriesLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.gold),
          );
        }

        if (state is CategoriesError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.red, size: 48),
                const SizedBox(height: 12),
                Text(state.message,
                    style: const TextStyle(color: AppTheme.textSecondary)),
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

        if (state is CategoriesLoaded) {
          final categories = state.categories;
          final filtered = _filterCategories(categories);

          if (categories.isEmpty) {
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
                    'No categories found',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _categorySearchController,
                  onChanged: (value) => setState(() => _categorySearchQuery = value),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: const TextStyle(color: AppTheme.textHint),
                    prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                    suffixIcon: _categorySearchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppTheme.textSecondary, size: 18),
                          onPressed: () {
                            _categorySearchController.clear();
                            setState(() => _categorySearchQuery = '');
                          },
                        )
                        : null,
                    filled: true,
                    fillColor: AppTheme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                      borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                      child: Text(
                        _categorySearchQuery.isNotEmpty
                            ? 'No results for "$_categorySearchQuery"'
                            : 'No categories found',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final category = filtered[index];
                        return _CategoryListItem(
                          category: category,
                          onTap: () {
                            setState(() => _selectedCategory = category);
                          },
                        );
                      },
                    ),
              ),
            ],
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildProductsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search ${_selectedCategory?.name ?? "products"}...',
              hintStyle: const TextStyle(color: AppTheme.textHint),
              prefixIcon:
              const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear,
                        color: AppTheme.textSecondary, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
              filled: true,
              fillColor: AppTheme.bgCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
              ),
            ),
          ),
        ),

        Expanded(
          child: BlocBuilder<ProductsCubit, ProductsState>(
            builder: (context, state) {
              if (state is ProductsLoading) {
                return const Center(
                    child:
                    CircularProgressIndicator(color: AppTheme.gold));
              }
              if (state is ProductsLoaded) {
                final filtered = _filterProducts(state.products);

                if (state.products.isEmpty) {
                  return const Center(
                    child: Text("No products found",
                        style:
                        TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No results for "$_searchQuery"'
                          : 'No products in this category',
                      style:
                      const TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ProductCard(product: filtered[index]),
                );
              }
              return const Center(
                  child: Text("No products found",
                      style:
                      TextStyle(color: AppTheme.textSecondary)));
            },
          ),
        ),
      ],
    );
  }
}


class _CategoryListItem extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryListItem({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (category.showLocalImage &&
                    category.localPath != null &&
                    category.localPath!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(category.localPath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View products',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EditProductScreen(product: product)),
        ).then((_) {
          context.read<ProductsCubit>().fetchProducts();
        }),
        leading: SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildImage(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
            if (product.alternativeName != null && product.alternativeName!.isNotEmpty)Text(
              product.alternativeName!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        subtitle: Text(
          "QR ${product.price.toStringAsFixed(2)}",
          style: const TextStyle(color: AppTheme.gold),
        ),
        trailing: const Icon(Icons.edit_outlined,
            color: AppTheme.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildImage() {
    final path = product.localPath;

    final bool shouldShowLocal = GlobalImageSettings().showLocalImages;

    if (shouldShowLocal && path != null && path.isNotEmpty) {
      if (path.startsWith('/') && path.length < 500) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
      } else {
        try {
          final cleanBase64 = path.trim().split(',').last;
          return Image.memory(
            base64Decode(cleanBase64),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        } catch (e) {
          debugPrint("Manage products image decode failed: $e");
        }
      }
    }

    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: AppTheme.bgCardElevated,
      child: const Icon(Icons.fastfood, color: AppTheme.textHint, size: 24),
    );
  }
}


class _GlobalImageToggleButton extends StatefulWidget {
  const _GlobalImageToggleButton();

  @override
  State<_GlobalImageToggleButton> createState() => _GlobalImageToggleButtonState();
}

class _GlobalImageToggleButtonState extends State<_GlobalImageToggleButton> {
  late bool _current;

  @override
  void initState() {
    super.initState();
    _current = GlobalImageSettings().showLocalImages;
    GlobalImageSettings().addListener(_onSettingChanged);
  }

  @override
  void dispose() {
    GlobalImageSettings().removeListener(_onSettingChanged);
    super.dispose();
  }

  void _onSettingChanged() {
    if (mounted) setState(() => _current = GlobalImageSettings().showLocalImages);
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GlobalImageBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _current ? 'Local images ON' : 'Local images OFF',
      child: GestureDetector(
        onTap: _openSheet,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _current
                ? AppTheme.gold.withValues(alpha: 0.15)
                : AppTheme.bgCardElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _current
                  ? AppTheme.gold.withValues(alpha: 0.5)
                  : AppTheme.bgBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _current
                      ? Icons.photo_library_rounded
                      : Icons.photo_library_outlined,
                  key: ValueKey(_current),
                  size: 15,
                  color: _current ? AppTheme.gold : AppTheme.textHint,
                ),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _current ? AppTheme.gold : AppTheme.textHint,
                ),
                child: Text(_current ? 'IMG ON' : 'IMG OFF'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalImageBottomSheet extends StatefulWidget {
  const _GlobalImageBottomSheet();

  @override
  State<_GlobalImageBottomSheet> createState() => _GlobalImageBottomSheetState();
}

class _GlobalImageBottomSheetState extends State<_GlobalImageBottomSheet> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = GlobalImageSettings().showLocalImages;
    GlobalImageSettings().addListener(_sync);
  }

  @override
  void dispose() {
    GlobalImageSettings().removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() => _value = GlobalImageSettings().showLocalImages);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.bgBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppTheme.textOnGold, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Image Display',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Affects all products & categories',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Container(height: 1, color: AppTheme.bgBorder),
          const SizedBox(height: 4),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await GlobalImageSettings().setShowLocalImages(!_value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _value
                        ? AppTheme.gold.withValues(alpha: 0.08)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _value
                          ? AppTheme.gold.withValues(alpha: 0.3)
                          : AppTheme.bgBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _value
                              ? AppTheme.gold.withValues(alpha: 0.15)
                              : AppTheme.bgCardElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _value
                              ? Icons.photo_library_rounded
                              : Icons.hide_image_outlined,
                          size: 20,
                          color: _value ? AppTheme.gold : AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _value
                                  ? 'Showing local images'
                                  : 'Showing network / gradient',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _value
                                  ? 'All products display their uploaded local image'
                                  : 'All products fall back to network image or gradient',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _value,
                        onChanged: (val) async {
                          await GlobalImageSettings().setShowLocalImages(val);
                        },
                        activeColor: AppTheme.gold,
                        inactiveThumbColor: AppTheme.textHint,
                        inactiveTrackColor: AppTheme.bgBorder,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: AppTheme.textHint),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Individual product settings still apply when this is ON.',
                    style: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}