import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Circular overlay icon button on the product image grid
/// (move up/down, delete). Extracted from `admin_image_manager_page.dart`.
final class AdminImageIconBtn extends StatelessWidget {
  const AdminImageIconBtn({super.key, required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scrim,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.white),
        ),
      ),
    );
  }
}
