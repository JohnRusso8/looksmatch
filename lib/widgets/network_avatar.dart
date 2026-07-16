import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.url,
    required this.radius,
  });

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.inputBackground,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: Icon(
        Icons.person_rounded,
        color: colors.headerSecondaryText,
        size: radius,
      ),
    );
  }
}

class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          color: colors.inputBackground,
          alignment: Alignment.center,
          child: Icon(
            Icons.person_rounded,
            color: colors.headerSecondaryText,
            size: 48,
          ),
        ),
      ),
    );
  }
}
