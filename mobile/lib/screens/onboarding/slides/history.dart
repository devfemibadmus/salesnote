import 'package:flutter/material.dart';

class HistorySlide extends StatelessWidget {
  const HistorySlide({super.key});

  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                width: 280,
                height: 260,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRect(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HistoryRow(
                          title: 'Receipt #1024',
                          subtitle: 'Rice • ₦12,500',
                          time: 'Today',
                          highlight: true,
                        ),
                        const SizedBox(height: 12),
                        const _HistoryRow(
                          title: 'Receipt #1023',
                          subtitle: 'Beans • ₦8,200',
                          time: 'Yesterday',
                        ),
                        const SizedBox(height: 12),
                        const _HistoryRow(
                          title: 'Receipt #1022',
                          subtitle: 'Palm oil • ₦5,000',
                          time: '2 days ago',
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.history, color: _primary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'All receipts saved automatically',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
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
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Receipt History',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'No more piles of paper. Every sale is stored as an e‑receipt, so you can find and share history anytime.',
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.title,
    required this.subtitle,
    required this.time,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final String time;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: highlight ? const Color(0xFF007AFF) : const Color(0xFFCBD5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
