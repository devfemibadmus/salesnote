import 'package:flutter/material.dart';

class QuickReceiptsSlide extends StatefulWidget {
  const QuickReceiptsSlide({super.key});

  @override
  State<QuickReceiptsSlide> createState() => _QuickReceiptsSlideState();
}

class _QuickReceiptsSlideState extends State<QuickReceiptsSlide>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF007AFF);
  static const _textMuted = Color(0xFF64748B);
  static const _softGray = Color(0xFFF1F5F9);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final float = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    final pulse = Tween<double>(
      begin: 1,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.white,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, float.value),
                  child: child,
                );
              },
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF93C5FD,
                            ).withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFEFF6FF), Colors.white],
                              ),
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Transform.rotate(
                                      angle: -0.05,
                                      child: Container(
                                        width: 120,
                                        height: 180,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: _softGray),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 16,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _Line(
                                              width: double.infinity,
                                              height: 8,
                                            ),
                                            const SizedBox(height: 6),
                                            _Line(width: 70, height: 8),
                                            const SizedBox(height: 16),
                                            _Line(
                                              width: double.infinity,
                                              height: 4,
                                              color: const Color(0xFFF8FAFC),
                                            ),
                                            const SizedBox(height: 6),
                                            _Line(
                                              width: double.infinity,
                                              height: 4,
                                              color: const Color(0xFFF8FAFC),
                                            ),
                                            const SizedBox(height: 6),
                                            _Line(
                                              width: double.infinity,
                                              height: 4,
                                              color: const Color(0xFFF8FAFC),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -18,
                                      top: 70,
                                      child: AnimatedBuilder(
                                        animation: _controller,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: pulse.value,
                                            child: child,
                                          );
                                        },
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: const BoxDecoration(
                                            color: _primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0x4D93C5FD),
                                                blurRadius: 12,
                                                offset: Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.send,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: 0.6 + (_controller.value * 0.4),
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 64,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Positioned(
                            top: 18,
                            left: 18,
                            child: Icon(
                              Icons.receipt_long,
                              size: 36,
                              color: Color(0x33007AFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Create and share receipts fast.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.width,
    required this.height,
    this.color = const Color(0xFFE2E8F0),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
