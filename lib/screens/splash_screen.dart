import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Animated launch screen — wipes the LooksMatch logo (assets/branding/
/// looksmatch_logo.svg, an auto-traced single fused shape covering the LM
/// monogram, heart, and wordmark together — see conversation) into view via
/// a moving diagonal mask, then calls [onFinished] so the caller can swap in
/// the real app content. Background is fixed white regardless of system
/// theme, matching the logo artwork (black mark on white).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), widget.onFinished);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOutCubic.transform(_controller.value);
            final scale = 0.96 + (0.04 * t);

            return Transform.scale(
              scale: scale,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) =>
                    _wipeGradient(t).createShader(bounds),
                child: child,
              ),
            );
          },
          child: SvgPicture.asset(
            'assets/branding/looksmatch_logo.svg',
            width: 240,
          ),
        ),
      ),
    );
  }

  // A diagonal band sweeps from top-left to bottom-right, growing a
  // permanently-revealed region behind it rather than just passing over —
  // stops are monotonically non-decreasing, which Gradient requires.
  LinearGradient _wipeGradient(double t) {
    const softEdge = 0.18;
    final edge = t * (1 + softEdge);
    final softStart = (edge - softEdge).clamp(0.0, 1.0);
    final softEnd = edge.clamp(0.0, 1.0);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Colors.black,
        Colors.black,
        Colors.transparent,
        Colors.transparent,
      ],
      stops: [0.0, softStart, softEnd, 1.0],
    );
  }
}
