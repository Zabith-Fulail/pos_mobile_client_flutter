import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/app_theme.dart';
import '../../cubit/order_entry/order_entry_cubit.dart';
import '../../cubit/order_entry/order_entry_state.dart';

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key});

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final TextEditingController _referenceController =
  TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _referenceFocusNode = FocusNode();
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _pinController.dispose();
    _referenceFocusNode.dispose();
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
          'Order Summary',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.bgBorder),
        ),
      ),
      body: BlocConsumer<OrderEntryCubit, OrderEntryState>(
        listener: (context, state) {
          if (state is OrderSubmissionSuccess) {
            _showSuccessDialog(context, state);
          } else if (state is OrderEntryError) {
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
        builder: (context, state) {
          if (state is OrderEntryLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.gold,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 16),
                  Text('Sending to kitchen...',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            );
          }

          if (state is! OrderEntryLoaded) return const SizedBox();

          return Column(
            children: [
              // Items list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = state.cartItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border:
                        Border.all(color: AppTheme.bgBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.quantity}×',
                              style: const TextStyle(
                                color: AppTheme.textOnGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight:
                                        FontWeight.w600)),
                                if (item.modifiers.isNotEmpty)
                                  ...item.modifiers.map(
                                        (m) => Text('+ ${m.name}',
                                        style: const TextStyle(
                                            color: AppTheme
                                                .textSecondary,
                                            fontSize: 12)),
                                  ),
                                if (item.note.isNotEmpty)
                                  Text('Note: ${item.note}',
                                      style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      )),
                              ],
                            ),
                          ),
                          Text(
                            'QR ${item.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Checkout panel
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  border: const Border(
                      top: BorderSide(color: AppTheme.bgBorder)),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Grand total
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E1E0A),
                              Color(0xFF2A2510)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.gold
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14)),
                            Text(
                              'QR ${state.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Reference
                      _buildInputLabel('Order Reference'),
                      const SizedBox(height: 6),
                      _buildFormField(
                        controller: _referenceController,
                        focusNode: _referenceFocusNode,
                        hint: 'Customer name or table number',
                        icon: Icons.person_outline_rounded,
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // PIN
                      _buildInputLabel('Waitress PIN'),
                      const SizedBox(height: 6),
                      _buildFormField(
                        controller: _pinController,
                        hint: '••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePin,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'PIN required' : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textHint,
                            size: 18,
                          ),
                          onPressed: () => setState(
                                  () => _obscurePin = !_obscurePin),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Place order button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                              AppTheme.gold.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _placeOrder(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14)),
                          ),
                          icon: const Icon(
                              Icons.send_rounded,
                              color: AppTheme.textOnGold,
                              size: 20),
                          label: const Text(
                            'SEND TO KITCHEN',
                            style: TextStyle(
                              color: AppTheme.textOnGold,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputLabel(String text) => Text(
    text,
    style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500),
  );

  Widget _buildFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool obscure = false,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(color: AppTheme.textHint, fontSize: 13),
        filled: true,
        fillColor: AppTheme.bgCard,
        prefixIcon: Icon(icon, color: AppTheme.textHint, size: 18),
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.red),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  void _placeOrder(BuildContext context) {
    _referenceFocusNode.unfocus();
    context.read<OrderEntryCubit>().submitOrder(
      customerId: _referenceController.text,
      customerName: _referenceController.text,
      orderType: 2,
    );
  }

  void _showSuccessDialog(
      BuildContext context, OrderSubmissionSuccess state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.green.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Order Sent!',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              Text(
                'KOT #${state.response.kitchenSaleId}',
                style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Order successfully pushed\nto the kitchen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<OrderEntryCubit>().resetAfterSubmission();
                    Navigator.pop(context);
                  },
                  child: const Text('New Order',
                      style: TextStyle(
                        color: AppTheme.textOnGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}