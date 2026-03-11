import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/currency.dart';

class SmartAnalyticsSlide extends StatefulWidget {
  const SmartAnalyticsSlide({super.key});

  @override
  State<SmartAnalyticsSlide> createState() => _SmartAnalyticsSlideState();
}

class _SmartAnalyticsSlideState extends State<SmartAnalyticsSlide> {
  static const _primary = Color(0xFF007AFF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  static const _cardCount = 3;
  int _page = 1000;
  final PageController _controller = PageController(initialPage: 1000);
  int _cardIndex = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _page += 1;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSalesAmount = CurrencyService.format(450200, decimalDigits: 0);
    final todaysSalesAmount = CurrencyService.format(98500, decimalDigits: 0);
    final weeklySalesAmount = _formatCompactAmount(1200000);

    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.white,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  onPageChanged: (value) =>
                      setState(() => _cardIndex = value % _cardCount),
                  itemBuilder: (context, index) {
                    final page = index % _cardCount;
                    switch (page) {
                      case 0:
                        return _AnalyticsCard(
                          title: 'Total Sales',
                          period: 'This Month',
                          amount: totalSalesAmount,
                          delta: '+12.5%',
                          deltaContext: 'vs last month',
                          trendUp: true,
                          chart: const _BarChart(
                            bars: [0.3, 0.45, 0.35, 0.65, 0.55, 0.85, 1.0],
                          ),
                        );
                      case 1:
                        return _AnalyticsCard(
                          title: 'Today’s Sales',
                          period: 'Today',
                          amount: todaysSalesAmount,
                          delta: '+6.1%',
                          deltaContext: 'vs yesterday, same time',
                          trendUp: true,
                          chart: const _PulseBarsChart(
                            bars: [0.25, 0.4, 0.58, 0.46, 0.65, 0.78, 0.9],
                          ),
                        );
                      default:
                        return _AnalyticsCard(
                          title: 'Weekly Sales',
                          period: 'Last 7 Days',
                          amount: weeklySalesAmount,
                          delta: '-3.8%',
                          deltaContext: 'vs previous week',
                          trendUp: false,
                          chart: const _CompareBarsChart(
                            thisWeek: [0.42, 0.58, 0.66, 0.48, 0.74, 0.63, 0.57],
                            lastWeek: [0.5, 0.61, 0.69, 0.53, 0.79, 0.67, 0.61],
                          ),
                        );
                    }
                  },
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Dot(size: 6, color: _cardIndex == 0 ? _primary : const Color(0xFFE2E8F0)),
                      _Dot(size: 16, color: _cardIndex == 1 ? _primary : const Color(0xFFE2E8F0)),
                      _Dot(size: 6, color: _cardIndex == 2 ? _primary : const Color(0xFFE2E8F0)),
                    ],
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
                'Smart Sales Analysis',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Track your shop’s performance with simple daily, weekly, and monthly reports. Grow your business with data.',
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

  String _formatCompactAmount(num amount) {
    final context = CurrencyService.resolveContext();
    try {
      return NumberFormat.compactCurrency(
        locale: context.locale,
        symbol: context.symbol,
        decimalDigits: 1,
      ).format(amount);
    } catch (_) {
      return CurrencyService.format(amount, decimalDigits: 0);
    }
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.period,
    required this.amount,
    required this.delta,
    required this.deltaContext,
    required this.trendUp,
    required this.chart,
  });

  final String title;
  final String period;
  final String amount;
  final String delta;
  final String deltaContext;
  final bool trendUp;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Container(
            width: 280,
            height: 240,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Spacer(),
                chart,
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    5,
                    (_) => Container(
                      width: 16,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 6,
          top: 40,
          child: Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      trendUp ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: trendUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      delta,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: trendUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  deltaContext,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.heightFactor, required this.opacity});

  final double heightFactor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 120 * heightFactor,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(opacity),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars});

  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars
          .map((height) => _Bar(heightFactor: height, opacity: height))
          .toList(),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _PulseBarsChart extends StatelessWidget {
  const _PulseBarsChart({required this.bars});

  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((value) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 110 * value.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF60A5FA), Color(0xFF007AFF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBFDBFE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CompareBarsChart extends StatelessWidget {
  const _CompareBarsChart({
    required this.thisWeek,
    required this.lastWeek,
  });

  final List<double> thisWeek;
  final List<double> lastWeek;

  @override
  Widget build(BuildContext context) {
    final count = thisWeek.length < lastWeek.length ? thisWeek.length : lastWeek.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(count, (i) {
        final current = thisWeek[i].clamp(0.0, 1.0);
        final previous = lastWeek[i].clamp(0.0, 1.0);
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    height: 100 * previous,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFDBFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Container(
                    height: 100 * current,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
