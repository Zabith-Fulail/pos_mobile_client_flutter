import 'dart:convert';
import 'dart:io';

import 'package:d_pos/features/presentation/views/main_dashboard/widget/drawer_item.dart';
import 'package:d_pos/features/presentation/views/main_dashboard/widget/product_list_item.dart';
import 'package:d_pos/features/presentation/views/main_dashboard/widget/qty_button.dart';
import 'package:d_pos/features/presentation/views/main_dashboard/widget/ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../../core/service/global_image_settings.dart';
import '../../../../utils/app_theme.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/order_entry/order_entry_cubit.dart';
import '../../cubit/order_entry/order_entry_state.dart';
import '../../widget/product_image_popup.dart';
import '../../widget/voice_order_bar.dart';
import '../manage_categories/manage_categories_screen.dart';
import '../manage_featured/manage_images_screen.dart';
import '../manage_featured/manage_videos_screen.dart';
import '../manage_products/manage_products_screen.dart';
import 'edit_item_screen.dart';
import 'featured/video_carousel_tab.dart';
import 'order_summary_screen.dart';

class MainPosScreen extends StatefulWidget {
  const MainPosScreen({super.key});

  @override
  State<MainPosScreen> createState() => _MainPosScreenState();
}

class _MainPosScreenState extends State<MainPosScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  final LocalDataSource _localDataSource = sl<LocalDataSource>();
  final _videoCarouselKey = GlobalKey<State>();
  late String branchName = "";
  static const String _foodImg =
      'https://images.unsplash.com/photo-1606787366850-de6330128bfc?q=80&w=300&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    context.read<OrderEntryCubit>().loadInitialData();
    getBranchName();
  }

  Future<void> getBranchName() async {
    branchName = await _localDataSource.getBranch();
    if (mounted) setState(() {});
  }


  void _onTabChanged() {
    if (_tabController.index == 3) {
      final state = _videoCarouselKey.currentState;
      if (state != null) {
        // Call reload method dynamically
        (state as dynamic).reload();
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  PreferredSizeWidget _buildAppBar(OrderEntryState state) {
    final cartCount = state is OrderEntryLoaded ? state.cartItems.length : 0;

    return AppBar(
      backgroundColor: AppTheme.bgSurface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppTheme.textOnGold,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sample Restaurant',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (branchName.isNotEmpty)
                Text(
                  branchName,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: AppTheme.bgSurface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.gold,
            indicatorWeight: 2.5,
            labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: [
              const Tab(text: 'Categories'),
              const Tab(text: 'Products'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cart'),
                    if (cartCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textOnGold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Featured',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderEntryCubit, OrderEntryState>(
      builder: (context, state) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppTheme.bgBase,
          bottomNavigationBar: state is OrderEntryLoaded
              ? VoiceOrderBar(
            onConfirm: (text) async {
              final result = await context.read<OrderEntryCubit>().submitVoiceOrder(text);
              if (result.unmatchedItemNames.isNotEmpty && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Not on menu, please add manually: ${result.unmatchedItemNames.join(", ")}',
                    ),
                    backgroundColor: AppTheme.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
          )
              : null,
          drawer: _buildSideDrawer(context),
          appBar: _buildAppBar(state),
          body: _handleBody(state),
        );
      },
    );
  }

  Widget _handleBody(OrderEntryState state) {
    if (state is OrderEntryLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                color: AppTheme.gold,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preparing menu...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state is OrderEntryError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.textHint,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed:
                  () => context.read<OrderEntryCubit>().loadInitialData(),
              icon: const Icon(Icons.refresh, color: AppTheme.gold),
              label: const Text(
                'Retry',
                style: TextStyle(color: AppTheme.gold),
              ),
            ),
          ],
        ),
      );
    }

    if (state is OrderEntryLoaded) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryGrid(state),
          _buildProductList(state),
          _buildCartView(state),
          VideoCarouselTab(key: _videoCarouselKey),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildCategoryGrid(OrderEntryLoaded state) {
    final cats = state.categories;
    final List<Widget> rows = [];
    int i = 0;

    while (i < cats.length) {
      final isHeroSlot = (i % 5 == 0);

      if (isHeroSlot) {
        final cat = cats[i];
        rows.add(
          _CategoryCard(
            category: cat,
            index: i,
            isSelected: cat.id == state.selectedCategory.id,
            isHero: true,
            onTap: () {
              _searchController.clear();
              context.read<OrderEntryCubit>().searchProduct('');
              context.read<OrderEntryCubit>().selectCategory(cat);
              _tabController.animateTo(1);
            },
          ),
        );
        i++;
      } else {
        final catA = cats[i];
        final catB = i + 1 < cats.length ? cats[i + 1] : null;
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryCard(
                  category: catA,
                  index: i,
                  isSelected: catA.id == state.selectedCategory.id,
                  isHero: false,
                  onTap: () {
                    _searchController.clear();
                    context.read<OrderEntryCubit>().searchProduct('');
                    context.read<OrderEntryCubit>().selectCategory(catA);
                    _tabController.animateTo(1);
                  },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child:
                    catB != null
                        ? _CategoryCard(
                          category: catB,
                          index: i + 1,
                          isSelected: catB.id == state.selectedCategory.id,
                          isHero: false,
                          onTap: () {
                            _searchController.clear();
                            context.read<OrderEntryCubit>().searchProduct('');
                            context.read<OrderEntryCubit>().selectCategory(
                              catB,
                            );
                            _tabController.animateTo(1);
                          },
                        )
                        : const SizedBox(),
              ),
            ],
          ),
        );
        i += catB != null ? 2 : 1;
      }
      rows.add(SizedBox(height: 12.h));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: rows,
    );
  }


  Widget _buildProductList(OrderEntryLoaded state) {
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
            child: TextField(
              controller: _searchController,
              onChanged: context.read<OrderEntryCubit>().searchProduct,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search ${state.selectedCategory.name}...',
                hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14.sp),
                filled: true,
                fillColor: AppTheme.bgCard,
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textHint,
                  size: 20.sp,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.close,
                            color: AppTheme.textHint,
                            size: 18.sp,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            context.read<OrderEntryCubit>().searchProduct('');
                            setState(() {});
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: AppTheme.bgBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: AppTheme.bgBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(
                    color: AppTheme.gold,
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
          if (state.currentProducts.isEmpty)
            Expanded(child: _buildEmptyState('No items found'))
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                itemCount: state.currentProducts.length,
                itemBuilder: (context, index) {
                  final product = state.currentProducts[index];
                  final isInCart = state.cartItems.any(
                    (i) => i.product.id == product.id,
                  );
                  return InkWell(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      showProductImagePopup(context, product);
                    },
                    child: ProductListItem(
                      product: product,
                      isInCart: isInCart,
                      imageUrl: _foodImg,
                      onAdd:
                          () => context.read<OrderEntryCubit>().addToCart(
                            product,
                          ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildCartView(OrderEntryLoaded state) {
    if (state.cartItems.isEmpty) {
      return _buildEmptyState(
        'Your cart is empty',
        icon: Icons.shopping_basket_outlined,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            itemCount: state.cartItems.length,
            itemBuilder: (context, index) {
              final item = state.cartItems[index];
              return _CartItem(
                item: item,
                onIncrement:
                    () => context.read<OrderEntryCubit>().updateQuantity(
                      item.uuid,
                      1,
                    ),
                onDecrement:
                    () => context.read<OrderEntryCubit>().updateQuantity(
                      item.uuid,
                      -1,
                    ),
                onRemove:
                    () => context.read<OrderEntryCubit>().removeItem(item.uuid),
                onCustomize:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => BlocProvider.value(
                              value: context.read<OrderEntryCubit>(),
                              child: EditItemScreen(item: item),
                            ),
                      ),
                    ),
              );
            },
          ),
        ),
        _buildCartFooter(state),
      ],
    );
  }

  Widget _buildCartFooter(OrderEntryLoaded state) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        border: const Border(top: BorderSide(color: AppTheme.bgBorder)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              Text(
                'QR ${state.grandTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => BlocProvider.value(
                              value: context.read<OrderEntryCubit>(),
                              child: const OrderSummaryScreen(),
                            ),
                      ),
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: Icon(
                  Icons.receipt_outlined,
                  color: AppTheme.textOnGold,
                  size: 20.sp,
                ),
                label: Text(
                  'Place Order',
                  style: TextStyle(
                    color: AppTheme.textOnGold,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSideDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.bgSurface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1C2C), Color(0xFF21233A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppTheme.textOnGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Restaurant',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${branchName.isNotEmpty ? branchName : ''} POS System',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DrawerItem(
            icon: Icons.category_outlined,
            label: 'Manage Categories',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageCategoriesScreen(),
                ),
              ).then((_) {
                context.read<OrderEntryCubit>().refreshAllLocalData();
              });
            },
          ),
          DrawerItem(
            icon: Icons.inventory_2_outlined,
            label: 'Manage Products',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageProductsScreen()),
              ).then((_) {
                context.read<OrderEntryCubit>().refreshAllLocalData();
              });
            },
          ),
          DrawerItem(
            icon: Icons.photo_library_outlined,
            label: 'Manage Images',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageImagesScreen()),
              ).then((_) {
                context.read<OrderEntryCubit>().refreshAllLocalData();
                if (_tabController.index == 3) {
                  final state = _videoCarouselKey.currentState;
                  if (state != null) {
                    (state as dynamic).reload();
                  }
                }
              });
            },
          ),
          DrawerItem(
            icon: Icons.video_library_outlined,
            label: 'Manage Videos',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageVideosScreen()),
              ).then((_) {
                context.read<OrderEntryCubit>().refreshAllLocalData();
                if (_tabController.index == 3) {
                  final state = _videoCarouselKey.currentState;
                  if (state != null) {
                    (state as dynamic).reload();
                  }
                }
              });
            },
          ),

          const Spacer(),
          Container(height: 1, color: AppTheme.bgBorder),
          const SizedBox(height: 8),
          DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            iconColor: AppTheme.red,
            labelColor: AppTheme.red,
            onTap: () => _showLogoutDialog(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.red,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to logout?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
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
                          onPressed: () async {
                            await sl<LocalDataSource>().clearAuthToken();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                'kLoginScreen',
                                (r) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Logout',
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

  Widget _buildEmptyState(
    String msg, {
    IconData icon = Icons.search_off_rounded,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.textHint),
          const SizedBox(height: 14),
          Text(
            msg,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}


const List<List<Color>> _kCategoryPalette = [
  [Color(0xFFC8973A), Color(0xFFE8C870), Color(0xFFFFE4A0)],
  [Color(0xFFD94F3F), Color(0xFFFF8C69), Color(0xFFFFBBA0)],
  [Color(0xFF1E8F72), Color(0xFF3ECFA3), Color(0xFFA0FFDE)],
  [Color(0xFF6A4FD6), Color(0xFFA882FF), Color(0xFFD4C0FF)],
  [Color(0xFF2A6FD4), Color(0xFF62AAFF), Color(0xFFC0DEFF)],
  [Color(0xFFBF3F7A), Color(0xFFFF82B8), Color(0xFFFFCCE8)],
  [Color(0xFFD47020), Color(0xFFFFAA50), Color(0xFFFFDFAA)],
  [Color(0xFF3A9048), Color(0xFF76D670), Color(0xFFBCF0B8)],
];

IconData _iconForCategory(String name) {
  final n = name.toLowerCase();
  if (n.contains('karak') || n.contains('tea') || n.contains('chai'))
    return Icons.emoji_food_beverage_rounded;
  if (n.contains('coffee') || n.contains('hot drink') || n.contains('espresso'))
    return Icons.local_cafe_rounded;
  if (n.contains('cold') ||
      n.contains('juice') ||
      n.contains('shake') ||
      n.contains('smoothie') ||
      n.contains('drink'))
    return Icons.local_drink_rounded;
  if (n.contains('burger') || n.contains('sandwich') || n.contains('wrap'))
    return Icons.lunch_dining_rounded;
  if (n.contains('pizza')) return Icons.local_pizza_rounded;
  if (n.contains('rice') || n.contains('biryani') || n.contains('kabsa'))
    return Icons.rice_bowl_rounded;
  if (n.contains('salad') || n.contains('veg') || n.contains('green'))
    return Icons.eco_rounded;
  if (n.contains('dessert') ||
      n.contains('sweet') ||
      n.contains('cake') ||
      n.contains('pastry'))
    return Icons.cake_rounded;
  if (n.contains('snack') ||
      n.contains('starter') ||
      n.contains('appetizer') ||
      n.contains('side'))
    return Icons.tapas_rounded;
  if (n.contains('soup') || n.contains('broth'))
    return Icons.soup_kitchen_rounded;
  if (n.contains('breakfast') || n.contains('egg'))
    return Icons.free_breakfast_rounded;
  if (n.contains('seafood') || n.contains('fish'))
    return Icons.set_meal_rounded;
  if (n.contains('chicken') || n.contains('meat') || n.contains('grill'))
    return Icons.outdoor_grill_rounded;
  if (n.contains('special') || n.contains('chef')) return Icons.star_rounded;
  return Icons.restaurant_menu_rounded;
}


class _CategoryCard extends StatefulWidget {
  final CategoryModel category;
  final int index;
  final bool isSelected;
  final bool isHero;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isSelected,
    required this.isHero,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    Future.delayed(Duration(milliseconds: 20 + widget.index * 55), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double cardHeight = widget.isHero ? 160.0 : 130.0;
    final icon = _iconForCategory(widget.category.name);

    BoxDecoration buildCardDecoration() {
      final List<Color> palette =
          _kCategoryPalette[widget.index % _kCategoryPalette.length];
      final gradStart = palette[0];
      final gradEnd = palette[1];

      ImageProvider? imageProvider;
      final String? path = widget.category.localPath;
      final bool shouldShowLocal = GlobalImageSettings().showLocalImages;
      if (shouldShowLocal && path != null && path.isNotEmpty) {
        if (path.startsWith('/') &&
            path.length < 500 &&
            !path.contains(RegExp(r'[+=\\]'))) {
          final file = File(path);
          if (file.existsSync()) {
            imageProvider = FileImage(file);
          }
        } else {
          try {
            imageProvider = MemoryImage(base64Decode(path.trim()));
          } catch (e) {
            debugPrint(
              "Base64 decode failed for Category ${widget.category.id}: $e",
            );
          }
        }
      }

      if (imageProvider == null &&
          widget.category.imageUrl != null &&
          widget.category.imageUrl!.isNotEmpty) {
        imageProvider = NetworkImage(widget.category.imageUrl!);
      }

      final border = Border.all(
        color:
            widget.isSelected
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
        width: widget.isSelected ? 2 : 1,
      );
      final shadow = BoxShadow(
        color: gradStart.withValues(alpha: widget.isSelected ? 0.55 : 0.3),
        blurRadius: widget.isSelected ? 20 : 10,
        offset: const Offset(0, 5),
      );

      if (imageProvider != null) {
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          border: border,
          boxShadow: [shadow],
        );
      } else {
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [gradStart, gradEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: border,
          boxShadow: [shadow],
        );
      }
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: cardHeight,
              decoration: buildCardDecoration(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  children: [
                    if (widget.category.localPath != null &&
                        widget.category.localPath!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.2),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    Positioned(
                      top: -28,
                      right: -28,
                      child: Ring(
                        size: 130,
                        color: Colors.white,
                        opacity: 0.05,
                      ),
                    ),
                    Positioned(
                      top: -10,
                      right: -10,
                      child: Ring(size: 80, color: Colors.white, opacity: 0.08),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Ring(size: 80, color: Colors.white, opacity: 0.04),
                    ),
                    widget.isHero
                        ? _buildHeroContent(icon)
                        : _buildCompactContent(icon),
                    if (widget.isSelected)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroContent(IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap to explore  →',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _buildCompactContent(IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16,8,16,16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const Spacer(),
          Text(
            widget.category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                'View items',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _CartItem extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onCustomize;

  const _CartItem({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    final cartImgWidth = 120.w;
    final cartImgHeight = 72.h;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.bgBorder),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: cartImgWidth,
                height: cartImgHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  color: AppTheme.bgCardElevated,
                ),
                clipBehavior: Clip.hardEdge,
                child: _buildProductImage(),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.modifiers.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      ...item.modifiers.map(
                        (m) => Text(
                          '+ ${m.name}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ],
                    if (item.note.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Note: ${item.note}',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 11.sp,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'QR ${item.total.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCardElevated,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    QtyBtn(
                      icon: Icons.remove,
                      onTap: onDecrement,
                      color: AppTheme.red,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Text(
                        '${item.quantity}'.padLeft(2, '0'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                    QtyBtn(
                      icon: Icons.add,
                      onTap: onIncrement,
                      color: AppTheme.green,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCustomize,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.bgBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  icon: Icon(
                    Icons.tune_rounded,
                    color: AppTheme.blue,
                    size: 16.sp,
                  ),
                  label: Text(
                    'Customize',
                    style: TextStyle(color: AppTheme.blue, fontSize: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.textHint,
                  size: 20.sp,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.red.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    final String? path = item.product.localPath;
    final bool shouldShowLocal = GlobalImageSettings().showLocalImages;
    if (shouldShowLocal && path != null && path.isNotEmpty) {
      if (path.startsWith('/') && path.length < 500) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildUrlFallback(),
          );
        }
      } else {
        try {
          final cleanBase64 = path.trim().split(',').last;
          return Image.memory(
            base64Decode(cleanBase64),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildUrlFallback(),
          );
        } catch (e) {
          debugPrint("Cart image Base64 decode failed: $e");
        }
      }
    }

    return _buildUrlFallback();
  }

  Widget _buildUrlFallback() {
    if (item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty) {
      return Image.network(
        item.product.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return Image.network(
      'https://images.unsplash.com/photo-1606787366850-de6330128bfc?q=80&w=300&auto=format&fit=crop',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.bgCardElevated,
      alignment: Alignment.center,
      child: Icon(Icons.fastfood, color: AppTheme.textHint, size: 28.sp),
    );
  }
}
