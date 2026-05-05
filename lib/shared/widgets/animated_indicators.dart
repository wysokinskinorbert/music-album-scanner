import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Animated checkmark for success states.
class AnimatedSuccessIndicator extends StatefulWidget {
  final String? message;
  final VoidCallback? onComplete;

  const AnimatedSuccessIndicator({super.key, this.message, this.onComplete});

  @override
  State<AnimatedSuccessIndicator> createState() =>
      _AnimatedSuccessIndicatorState();
}

class _AnimatedSuccessIndicatorState extends State<AnimatedSuccessIndicator>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late Animation<double> _scale;
  late Animation<double> _check;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _check = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOut),
    );

    _scaleController.forward().then((_) {
      _checkController.forward().then((_) {
        if (widget.onComplete != null) {
          Future.delayed(const Duration(milliseconds: 800), widget.onComplete!);
        }
      });
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scale,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.15),
            ),
            child: AnimatedBuilder(
              animation: _check,
              builder: (context, child) {
                return CustomPaint(
                  painter: _CheckPainter(progress: _check.value),
                  size: const Size(80, 80),
                );
              },
            ),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _check,
            child: Text(
              widget.message!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

/// Animated X mark for failure states.
class AnimatedFailIndicator extends StatefulWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AnimatedFailIndicator({super.key, this.message, this.onRetry});

  @override
  State<AnimatedFailIndicator> createState() => _AnimatedFailIndicatorState();
}

class _AnimatedFailIndicatorState extends State<AnimatedFailIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _rotation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scale,
          child: RotationTransition(
            turns: _rotation,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 40),
            ),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (widget.onRetry != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Animated pulsing scan indicator.
class AnimatedScanPulse extends StatefulWidget {
  final String? statusText;

  const AnimatedScanPulse({super.key, this.statusText});

  @override
  State<AnimatedScanPulse> createState() => _AnimatedScanPulseState();
}

class _AnimatedScanPulseState extends State<AnimatedScanPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = 1.0 + (_controller.value * 0.15);
            final opacity = 1.0 - (_controller.value * 0.5);
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 48,
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.statusText != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.statusText!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom painter for animated checkmark.
class _CheckPainter extends CustomPainter {
  final double progress;

  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw checkmark path
    final path = Path();
    path.moveTo(center.dx - 18, center.dy + 2);
    path.lineTo(center.dx - 4, center.dy + 14);
    path.lineTo(center.dx + 20, center.dy - 12);

    // Animate drawing
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      final length = metric.length * progress;
      canvas.drawPath(
        metric.extractPath(0, length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
