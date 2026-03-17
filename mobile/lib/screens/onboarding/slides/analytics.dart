import 'package:flutter/material.dart';

class SmartAnalyticsSlide extends StatefulWidget {
  const SmartAnalyticsSlide({super.key});

  @override
  State<SmartAnalyticsSlide> createState() => _SmartAnalyticsSlideState();
}

class _SmartAnalyticsSlideState extends State<SmartAnalyticsSlide>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF007AFF);
  static const _accent = Color(0xFFDC2626);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = Tween<double>(
      begin: -4,
      end: 4,
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
                  offset: Offset(0, offset.value),
                  child: child,
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 308,
                    height: 286,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF93C5FD).withValues(alpha: 0.22),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 18,
                          top: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 16,
                                  color: _primary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Live Cashier',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 20,
                          top: 20,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0x1ADC2626),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: _accent,
                              size: 28,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 22,
                          right: 22,
                          top: 82,
                          child: Column(
                            children: const [
                              _Bubble(
                                text: 'Create a receipt for John. Add 3 bags of rice.',
                                alignEnd: true,
                                tint: Color(0xFFF1F5F9),
                                textColor: _textDark,
                              ),
                              SizedBox(height: 12),
                              _Bubble(
                                text: 'Sure. I am preparing the receipt now.',
                                alignEnd: false,
                                tint: Color(0xFFEFF6FF),
                                textColor: _primary,
                              ),
                              SizedBox(height: 12),
                              _Bubble(
                                text: 'Wait, make that 2 bags.',
                                alignEnd: true,
                                tint: Color(0xFFF1F5F9),
                                textColor: _textDark,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 22,
                          right: 22,
                          bottom: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.autorenew_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Interrupt naturally while the agent is speaking',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
              'Talk naturally and interrupt anytime.',
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.alignEnd,
    required this.tint,
    required this.textColor,
  });

  final String text;
  final bool alignEnd;
  final Color tint;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
