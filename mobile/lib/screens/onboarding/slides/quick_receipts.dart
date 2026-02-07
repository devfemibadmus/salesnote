import 'package:flutter/material.dart';

class QuickReceiptsSlide extends StatelessWidget {
  const QuickReceiptsSlide({super.key});

  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);
  static const _softGray = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
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
                          color: const Color(0xFF93C5FD).withOpacity(0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFEFF6FF),
                                Colors.white,
                              ],
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
                                  Container(
                                    width: 120,
                                    height: 180,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _softGray),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 16,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _Line(width: double.infinity, height: 8),
                                        const SizedBox(height: 6),
                                        _Line(width: 70, height: 8),
                                        const SizedBox(height: 16),
                                        _Line(width: double.infinity, height: 4, color: const Color(0xFFF8FAFC)),
                                        const SizedBox(height: 6),
                                        _Line(width: double.infinity, height: 4, color: const Color(0xFFF8FAFC)),
                                        const SizedBox(height: 6),
                                        _Line(width: double.infinity, height: 4, color: const Color(0xFFF8FAFC)),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    right: -18,
                                    top: 70,
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
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: 64,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(99),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Quick E-Receipts',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Generate and share receipts instantly. No paper, no ink, no waste. Full history at your fingertips.',
                style: TextStyle(
                  fontSize: 18,
                  color: _textMuted,
                  height: 1.5,
                ),
              ),
            ],
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
