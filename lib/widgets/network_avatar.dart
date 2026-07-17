import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NetworkAvatar extends StatefulWidget {
  const NetworkAvatar({
    super.key,
    required this.url,
    required this.radius,
  });

  final String url;
  final double radius;

  @override
  State<NetworkAvatar> createState() => _NetworkAvatarState();
}

class _NetworkAvatarState extends State<NetworkAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant NetworkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // CircleAvatar draws `child` on top of `backgroundImage` regardless —
    // it doesn't hide it just because an image loaded — so the fallback
    // icon has to be conditional, not just an always-on overlay.
    final showImage = widget.url.isNotEmpty && !_failed;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: colors.inputBackground,
      backgroundImage: showImage ? NetworkImage(widget.url) : null,
      onBackgroundImageError: showImage
          ? (_, __) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: showImage
          ? null
          : Icon(
              Icons.person_rounded,
              color: colors.headerSecondaryText,
              size: widget.radius,
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
