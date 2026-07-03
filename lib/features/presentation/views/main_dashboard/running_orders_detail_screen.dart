import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../cubit/running_orders/running_orders_cubit.dart';
import '../../cubit/running_orders/running_orders_state.dart';

class RunningOrdersScreen extends StatelessWidget {
  const RunningOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RunningOrdersCubit>()..fetchRunningOrders(),
      child: const _RunningOrdersView(),
    );
  }
}

class _RunningOrdersView extends StatefulWidget {
  const _RunningOrdersView();

  @override
  State<_RunningOrdersView> createState() => _RunningOrdersViewState();
}

class _RunningOrdersViewState extends State<_RunningOrdersView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        context
            .read<RunningOrdersCubit>()
            .fetchRunningOrders(isBackgroundRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
          'Running Orders',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          BlocBuilder<RunningOrdersCubit, RunningOrdersState>(
            builder: (context, state) => IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppTheme.textSecondary, size: 22),
              onPressed: () => context
                  .read<RunningOrdersCubit>()
                  .fetchRunningOrders(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.bgBorder),
        ),
      ),
      body: BlocBuilder<RunningOrdersCubit, RunningOrdersState>(
        builder: (context, state) {
          if (state is RunningOrdersLoading) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.gold, strokeWidth: 2),
            );
          }

          if (state is RunningOrdersError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppTheme.textHint, size: 48),
                  const SizedBox(height: 12),
                  Text(state.message,
                      style: const TextStyle(
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context
                        .read<RunningOrdersCubit>()
                        .fetchRunningOrders(),
                    icon:
                    const Icon(Icons.refresh, color: AppTheme.gold),
                    label: const Text('Retry',
                        style: TextStyle(color: AppTheme.gold)),
                  ),
                ],
              ),
            );
          }

          if (state is RunningOrdersLoaded) {
            if (state.orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 52, color: AppTheme.textHint),
                    SizedBox(height: 14),
                    Text('No active orders',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.orders.length,
              itemBuilder: (context, index) {
                return _OrderCard(
                  order: state.orders[index],
                  index: index,
                  onPrint: (orderId) {
                    context.read<RunningOrdersCubit>().printOrder(
                      orderId,
                      onSuccess: (msg) =>
                          _showSnack(context, msg, isSuccess: true),
                      onError: (err) =>
                          _showSnack(context, err, isSuccess: false),
                    );
                  },
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showSnack(BuildContext context, String msg,
      {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? AppTheme.green : AppTheme.red,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ── ORDER CARD ─────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  final dynamic order;
  final int index;
  final ValueChanged<int> onPrint;

  const _OrderCard({
    required this.order,
    required this.index,
    required this.onPrint,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280 + 50),
    );
    Future.delayed(
      Duration(milliseconds: widget.index * 60),
          () { if (mounted) _ctrl.forward(); },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.bgBorder),
          ),
          child: Column(
            children: [
              // Header row
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Status dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.order.customerName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.order.saleNo,
                              style: const TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Total
                      Text(
                        'QR ${widget.order.totalPayable.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Print
                      _PrintBtn(
                          onTap: () => widget.onPrint(widget.order.id)),
                      const SizedBox(width: 6),

                      // Expand chevron
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _expanded ? 0.5 : 0,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textHint,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded details
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgBase,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                    border: const Border(
                        top: BorderSide(color: AppTheme.bgBorder)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ORDER DETAILS',
                        style: TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...widget.order.details
                          .map<Widget>((item) => Padding(
                        padding:
                        const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppTheme.goldGradient,
                                borderRadius:
                                BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.qty}×',
                                style: const TextStyle(
                                  color: AppTheme.textOnGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.menuName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              item.price.toStringAsFixed(2),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ))
                          .toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _PrintBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.blue.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_outlined,
                color: AppTheme.blue, size: 14),
            SizedBox(width: 4),
            Text('Print',
                style: TextStyle(
                    color: AppTheme.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}