import 'package:d_pos/features/presentation/views/main_dashboard/widget/voice_order_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/app_theme.dart';
import '../../../data/models/pos_models.dart';
import '../../cubit/order_entry/order_entry_cubit.dart';

class EditItemScreen extends StatefulWidget {
  final CartItem item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _noteController;
  late List<ModifierModel> _selectedModifiers;


  void _applyVoiceCommand(String spokenText) {
    final allModifiers = context.read<OrderEntryCubit>().availableModifiers;
    final text = spokenText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
    const negationWords = ['no', 'not', 'without', 'remove', 'skip'];
    const helperWords = ['add', 'extra', 'with'];
    const skipWords = {'any', 'the', 'some', 'a', 'an'};

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final consumedIndices = <int>{};

    final sortedMods = [...allModifiers]..sort(
      (a, b) => b.name.length.compareTo(a.name.length),
    );

    for (final mod in sortedMods) {
      final cleanModName = mod.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .trim();
      final modWords = cleanModName
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      if (modWords.isEmpty) continue;

      final overlap = modWords.where((w) => words.contains(w)).toList();
      if (overlap.isEmpty) continue;

      // Find the indices of these overlap words that are not yet consumed
      final indices = <int>[];
      for (final w in overlap) {
        int idx = -1;
        for (int i = 0; i < words.length; i++) {
          if (!consumedIndices.contains(i) && !indices.contains(i) && words[i] == w) {
            idx = i;
            break;
          }
        }
        if (idx != -1) {
          indices.add(idx);
        }
      }

      if (indices.isEmpty) continue;
      indices.sort();

      int? negOrHelperIdx;
      bool isNegated = false;

      final prev1 = indices.first - 1;
      if (prev1 >= 0 && !consumedIndices.contains(prev1)) {
        final w1 = words[prev1];
        if (negationWords.contains(w1)) {
          isNegated = true;
          negOrHelperIdx = prev1;
        } else if (helperWords.contains(w1)) {
          negOrHelperIdx = prev1;
        } else if (skipWords.contains(w1)) {
          final prev2 = indices.first - 2;
          if (prev2 >= 0 && !consumedIndices.contains(prev2)) {
            final w2 = words[prev2];
            if (negationWords.contains(w2)) {
              isNegated = true;
              negOrHelperIdx = prev2;
            } else if (helperWords.contains(w2)) {
              negOrHelperIdx = prev2;
            }
          }
        }
      }

      if (isNegated) {
        while (_getQty(mod) > 0) {
          _removeModifier(mod);
        }
      } else if (_getQty(mod) == 0) {
        _addModifier(mod);
      }

      // Mark the modifier words and any preceding negation/helper word as consumed
      consumedIndices.addAll(indices);
      if (negOrHelperIdx != null) {
        consumedIndices.add(negOrHelperIdx);
      }
    }

    // Filter out consumed words and filler words
    final fillerWords = {'please', 'make', 'it'};
    final remainderWords = <String>[];
    for (int i = 0; i < words.length; i++) {
      if (!consumedIndices.contains(i) && !fillerWords.contains(words[i])) {
        remainderWords.add(words[i]);
      }
    }

    final remainder = remainderWords.join(' ').trim();

    if (remainder.isNotEmpty) {
      setState(() {
        _noteController.text = _noteController.text.isEmpty
            ? remainder
            : '${_noteController.text}, $remainder';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.item.note);
    _selectedModifiers = List.from(widget.item.modifiers);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int _getQty(ModifierModel mod) =>
      _selectedModifiers.where((m) => m.id == mod.id).length;

  void _addModifier(ModifierModel mod) =>
      setState(() => _selectedModifiers.add(mod));

  void _removeModifier(ModifierModel mod) => setState(() {
    final idx = _selectedModifiers.indexWhere((m) => m.id == mod.id);
    if (idx != -1) _selectedModifiers.removeAt(idx);
  });

  @override
  Widget build(BuildContext context) {
    final allModifiers = context.read<OrderEntryCubit>().availableModifiers;

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: VoiceCaptureButton(onResult: _applyVoiceCommand, mini: true),
          ),
        ],

        backgroundColor: AppTheme.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Customize Item',
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cardGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.bgBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.fastfood_rounded,
                              color: AppTheme.textOnGold, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.product.name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'QR ${widget.item.product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppTheme.gold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Note field
                  _SectionHeader(
                    icon: Icons.edit_note_rounded,
                    title: 'Preparation Note',
                    subtitle: 'Optional',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Less spicy, extra sauce, hot...',
                      hintStyle: const TextStyle(
                          color: AppTheme.textHint, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: AppTheme.bgBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: AppTheme.bgBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.gold, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Modifiers
                  _SectionHeader(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Extras & Modifiers',
                    subtitle: '${_selectedModifiers.length} selected',
                  ),
                  const SizedBox(height: 14),

                  if (allModifiers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.bgBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'No modifiers available.',
                          style: TextStyle(color: AppTheme.textHint),
                        ),
                      ),
                    )
                  else
                    ...allModifiers.map((mod) {
                      final qty = _getQty(mod);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: qty > 0
                              ? AppTheme.gold.withValues(alpha: 0.06)
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: qty > 0
                                ? AppTheme.gold.withValues(alpha: 0.35)
                                : AppTheme.bgBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(mod.name,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15)),
                                  Text('+ QR ${mod.price}',
                                      style: const TextStyle(
                                          color: AppTheme.gold,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            // Qty stepper
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.bgCardElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  _StepBtn(
                                    icon: Icons.remove,
                                    color: qty > 0
                                        ? AppTheme.red
                                        : AppTheme.textHint,
                                    onTap: qty > 0
                                        ? () => _removeModifier(mod)
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$qty',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: qty > 0
                                            ? AppTheme.gold
                                            : AppTheme.textHint,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  _StepBtn(
                                    icon: Icons.add,
                                    color: AppTheme.green,
                                    onTap: () => _addModifier(mod),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Confirm button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              border:
              const Border(top: BorderSide(color: AppTheme.bgBorder)),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  context.read<OrderEntryCubit>().updateCartItemDetails(
                    widget.item.uuid,
                    _selectedModifiers,
                    _noteController.text,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_rounded,
                    color: AppTheme.textOnGold),
                label: const Text(
                  'CONFIRM CHANGES',
                  style: TextStyle(
                    color: AppTheme.textOnGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(subtitle,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StepBtn({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}