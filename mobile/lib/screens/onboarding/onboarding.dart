import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/local_cache.dart';
import 'slides/analytics.dart';
import 'slides/history.dart';
import 'slides/quick_receipts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _primary = Color(0xFF007AFF);

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await LocalCache.setOnboardingComplete(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                children: const [
                  QuickReceiptsSlide(),
                  SmartAnalyticsSlide(),
                  HistorySlide(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  _Dots(count: 3, index: _index),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_index == 0)
                        TextButton(
                          onPressed: _finish,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 64),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _index < 2 ? _next : _finish,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_index < 2 ? 'Next' : 'Get Started'),
                            if (_index < 2) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF007AFF);
    const inactiveColor = Color(0xFFE2E8F0);

    return Row(
      children: List.generate(count, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          height: 6,
          width: isActive ? 24 : 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
