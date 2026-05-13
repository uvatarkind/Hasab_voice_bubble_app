import 'package:flutter/material.dart';

class BubbleToggleButton extends StatefulWidget {
  const BubbleToggleButton({
    super.key,
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  State<BubbleToggleButton> createState() => _BubbleToggleButtonState();
}

class _BubbleToggleButtonState extends State<BubbleToggleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  static const _activeTop = Color(0xFFB38CFF);
  static const _activeBottom = Color(0xFF6B4DFF);
  static const _inactiveTop = Color(0xFF5BE7A9);
  static const _inactiveBottom = Color(0xFF1FAE6F);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    );
    _waveController.repeat();
  }

  @override
  void didUpdateWidget(covariant BubbleToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _waveController.repeat();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final waveColor = widget.isActive ? _activeTop : _inactiveTop;
        final topColor = widget.isActive ? _activeTop : _inactiveTop;
        final bottomColor = widget.isActive ? _activeBottom : _inactiveBottom;
        return CustomPaint(
          painter: _WavePainter(
            progress: _waveController.value,
            color: waveColor,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [topColor, bottomColor],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: bottomColor.withOpacity(0.4),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isActive ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.isActive ? 'Stop' : 'Start',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;
    final radius = baseRadius + (progress * 16);
    final opacity = (1 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withOpacity(0.5 * opacity);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
