import 'package:flutter/material.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';

class EmployeeAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const EmployeeAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.radius = 24,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final String resolvedUrl = ApiEndpoints.resolveImageUrl(avatarUrl);
    final String initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim()[0].toUpperCase()
        : 'E';

    final Color bgColor = backgroundColor ?? AppColors.primary;
    final Color txtColor = textColor ?? Colors.white;

    if (resolvedUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: NetworkImage(resolvedUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initial,
        style: TextStyle(
          color: txtColor,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
