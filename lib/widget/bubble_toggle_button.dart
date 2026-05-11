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
        final waveColor = widget.isActive
            ? const Color.fromARGB(255, 105, 33, 153)
            : Colors.green;
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
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive
                      ? const Color.fromARGB(255, 105, 33, 153)
                      : Colors.green,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.isActive ? const Color.fromARGB(255, 0, 0, 0) : Colors.green)
                              .withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isActive ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.isActive ? 'Stop' : 'Start',
                      style: const TextStyle(
                        fontSize: 18,
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
