import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/app_theme.dart';

class DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color labelColor;

  const DrawerItem({super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AppTheme.textSecondary,
    this.labelColor = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}
