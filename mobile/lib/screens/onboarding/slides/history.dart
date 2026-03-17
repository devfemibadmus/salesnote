import 'package:flutter/material.dart';

class HistorySlide extends StatefulWidget {
  const HistorySlide({super.key});

  @override
  State<HistorySlide> createState() => _HistorySlideState();
}

class _HistorySlideState extends State<HistorySlide>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
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
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, offset.value),
                    child: child,
                  );
                },
                child: Container(
                  width: 308,
                  height: 286,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: 18,
                        child: Container(
                          width: 156,
                          height: 228,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'New Receipt',
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _Field(label: 'Customer', value: 'John'),
                              const SizedBox(height: 8),
                              _Field(label: 'Items', value: 'Rice x2'),
                              const SizedBox(height: 8),
                              _Field(label: 'Total', value: '36,000'),
                              const Spacer(),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'Preview ready',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 18,
                        top: 24,
                        child: SizedBox(
                          width: 106,
                          child: Column(
                            children: const [
                              _MiniCard(
                                icon: Icons.receipt_long_rounded,
                                label: 'Receipts',
                              ),
                              SizedBox(height: 12),
                              _MiniCard(
                                icon: Icons.bar_chart_rounded,
                                label: 'Sales',
                              ),
                              SizedBox(height: 12),
                              _MiniCard(
                                icon: Icons.inventory_2_rounded,
                                label: 'Items',
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 20,
                        child: Container(
                          width: 176,
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xF70F172A),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: const [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0x332563EB),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Live cashier still running',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
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
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Keep moving while the cashier stays live.',
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: _HistorySlideState._textDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _HistorySlideState._primary, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: _HistorySlideState._textDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
