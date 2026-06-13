import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

// Segments ordered clockwise from top: 0%, 5%, 10%, 15%
const _kDiscounts = [0, 5, 10, 15];
const _kSegmentColors = [
  Color(0xFF90A4AE), // 0%  — blue-grey (no discount)
  AppColors.success, // 5%
  AppColors.warning, // 10%
  AppColors.primary, // 15%
];

/// Modal bottom sheet with a spin-wheel discount experience.
///
/// [onSpin] is called when the customer taps the spin button.
/// It must return `{'discountPercent': int, 'token': String}`.
///
/// For map booking, pass a callback that calls the `spin-booking-discount`
/// edge function. For quick booking, pass a local random generator now and
/// replace it with the real API call once the backend supports it.
///
/// Returns `{'discountPercent': int, 'token': String}` on confirm,
/// or `null` if the customer dismisses without completing the spin.
class SpinDiscountSheet extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() onSpin;

  const SpinDiscountSheet({super.key, required this.onSpin});

  @override
  State<SpinDiscountSheet> createState() => _SpinDiscountSheetState();
}

class _SpinDiscountSheetState extends State<SpinDiscountSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  double _currentAngle = 0;
  bool _loading = false;
  bool _spinning = false;
  bool _done = false;
  String? _error;
  int _discountPercent = 0;
  String _spinToken = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSpin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.onSpin();

      final discountPercent = result['discountPercent'] as int? ?? 0;
      final token = result['token'] as String? ?? '';

      // Map discountPercent to its segment index (default to 0 for unknown values)
      final segmentIndex = _kDiscounts.contains(discountPercent)
          ? _kDiscounts.indexOf(discountPercent)
          : 0;

      // Target angle so segment k lands under the top pointer after ~6 full CW rotations.
      // Derived from: segment k center is at local angle (-π/2 + k·π/2 + π/4).
      // For it to appear at world top (-π/2) after CW rotation θ: α_k + θ = -π/2 + 12π
      // → θ = 12π - segmentIndex·(π/2) - π/4
      final targetAngle = 12 * pi - segmentIndex * (pi / 2) - pi / 4;

      _controller.reset();
      final animation = Tween<double>(begin: 0, end: targetAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.decelerate),
      );
      _controller.addListener(() {
        if (mounted) setState(() => _currentAngle = animation.value);
      });

      setState(() {
        _loading = false;
        _spinning = true;
        _discountPercent = discountPercent;
        _spinToken = token;
      });

      await _controller.forward();

      if (mounted) setState(() { _spinning = false; _done = true; });
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.toString(); });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              loc.spinTitle,
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Wheel + fixed pointer at top
            SizedBox(
              width: 240,
              height: 265,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 22,
                    child: Transform.rotate(
                      angle: _currentAngle,
                      child: CustomPaint(
                        size: const Size(220, 220),
                        painter: _SpinWheelPainter(
                          discounts: _kDiscounts,
                          colors: _kSegmentColors,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 46,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            if (_error != null) ...[
              Text(
                loc.spinErrorMessage,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (_done) ...[
              Text(
                _discountPercent > 0
                    ? loc.spinDiscountWon(_discountPercent)
                    : loc.spinNoDiscount,
                style: AppTextStyles.titleMedium.copyWith(
                  color: _discountPercent > 0
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop({
                    'token': _spinToken,
                    'discountPercent': _discountPercent,
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(loc.spinConfirmButton),
                  ),
                ),
              ),
            ] else if (_spinning) ...[
              Text(
                loc.spinSpinning,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSpin,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _loading ? loc.spinLoading : loc.spinButtonSpin,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xs),

            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(loc.spinCancelButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinWheelPainter extends CustomPainter {
  final List<int> discounts;
  final List<Color> colors;

  const _SpinWheelPainter({required this.discounts, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final count = discounts.length;
    final sweepAngle = 2 * pi / count;

    for (int i = 0; i < count; i++) {
      final startAngle = -pi / 2 + i * sweepAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        Paint()..color = colors[i],
      );

      // White divider lines
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );

      // Percentage label at 62% of the radius
      final labelAngle = startAngle + sweepAngle / 2;
      final labelCenter = Offset(
        center.dx + radius * 0.62 * cos(labelAngle),
        center.dy + radius * 0.62 * sin(labelAngle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${discounts[i]}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, labelCenter - Offset(tp.width / 2, tp.height / 2));
    }

    // Center hub
    canvas.drawCircle(center, radius * 0.13, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius * 0.13,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinWheelPainter oldDelegate) => false;
}
