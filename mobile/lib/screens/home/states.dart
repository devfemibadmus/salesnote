part of 'home.dart';

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: const [
        _LoadingHeader(),
        SizedBox(height: 16),
        _LoadingProfileCard(),
        SizedBox(height: 14),
        _LoadingMetricCards(),
        SizedBox(height: 14),
        _LoadingChartCard(),
        SizedBox(height: 14),
        _LoadingRecentHeader(),
        SizedBox(height: 12),
        _LoadingSaleRow(),
        SizedBox(height: 10),
        _LoadingSaleRow(),
        SizedBox(height: 10),
        _LoadingSaleRow(),
        SizedBox(height: 10),
        _LoadingSaleRow(),
      ],
    );
  }
}

class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LoadingCircle(size: 56),
        SizedBox(width: 12),
        _LoadingLine(width: 150, height: 34),
        Spacer(),
        _LoadingCircle(size: 52),
        SizedBox(width: 12),
        _LoadingCircle(size: 52),
      ],
    );
  }
}

class _LoadingProfileCard extends StatelessWidget {
  const _LoadingProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E1EE)),
      ),
      child: Row(
        children: const [
          _LoadingBox(width: 84, height: 84),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingLine(width: double.infinity, height: 26),
                SizedBox(height: 12),
                _LoadingLine(width: 180, height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingMetricCards extends StatelessWidget {
  const _LoadingMetricCards();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 145,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _LoadingMetricCard(),
          SizedBox(width: 12),
          _LoadingMetricCard(),
          SizedBox(width: 12),
          _LoadingMetricCard(),
        ],
      ),
    );
  }
}

class _LoadingMetricCard extends StatelessWidget {
  const _LoadingMetricCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E1EE)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LoadingLine(width: 76, height: 22, tintBlue: true),
          SizedBox(height: 16),
          _LoadingLine(width: 122, height: 30),
          SizedBox(height: 16),
          _LoadingLine(width: 100, height: 20),
        ],
      ),
    );
  }
}

class _LoadingChartCard extends StatelessWidget {
  const _LoadingChartCard();

  @override
  Widget build(BuildContext context) {
    const bars = [130.0, 172.0, 86.0, 150.0, 196.0, 102.0, 132.0];
    return Container(
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E1EE)),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              _LoadingLine(width: 175, height: 30),
              Spacer(),
              _LoadingLine(width: 110, height: 42),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                bars.length,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _LoadingBox(
                      width: double.infinity,
                      height: bars[index],
                      borderRadius: 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LoadingLine(width: 32, height: 16),
              _LoadingLine(width: 32, height: 16),
              _LoadingLine(width: 32, height: 16),
              _LoadingLine(width: 32, height: 16),
              _LoadingLine(width: 32, height: 16),
              _LoadingLine(width: 32, height: 16),
              _LoadingLine(width: 32, height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingRecentHeader extends StatelessWidget {
  const _LoadingRecentHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LoadingLine(width: 170, height: 28),
        Spacer(),
        _LoadingLine(width: 86, height: 20),
      ],
    );
  }
}

class _LoadingSaleRow extends StatelessWidget {
  const _LoadingSaleRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E1EE)),
      ),
      child: Row(
        children: const [
          _LoadingCircle(size: 56),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingLine(width: 175, height: 22),
                SizedBox(height: 10),
                _LoadingLine(width: 110, height: 18),
              ],
            ),
          ),
          SizedBox(width: 12),
          _LoadingLine(width: 88, height: 32),
        ],
      ),
    );
  }
}

class _LoadingCircle extends StatelessWidget {
  const _LoadingCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return _LoadingBox(width: size, height: size, borderRadius: size / 2);
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine({
    required this.width,
    required this.height,
    this.tintBlue = false,
  });

  final double width;
  final double height;
  final bool tintBlue;

  @override
  Widget build(BuildContext context) {
    final color = tintBlue ? const Color(0xFFC6DAF2) : const Color(0xFFE5E7EB);
    return _LoadingBox(width: width, height: height, color: color);
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({
    required this.width,
    required this.height,
    this.borderRadius = 10,
    this.color = const Color(0xFFE5E7EB),
  });

  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onNotification,
  });
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onNotification;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _DashboardEmptyHeader(onNotification: onNotification),
        const SizedBox(height: 14),
        const _DashboardRevenueCard(),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _DashboardSmallMetricCard(title: 'Orders', value: '0'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _DashboardSmallMetricCard(title: 'Customers', value: '0'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD9E1EE)),
          ),
          child: Column(
            children: [
              const _DashboardEmptyVisual(),
              const SizedBox(height: 14),
              const Text(
                'Dashboard unavailable',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateSale, required this.onNotification});
  final VoidCallback onCreateSale;
  final VoidCallback onNotification;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _DashboardEmptyHeader(onNotification: onNotification),
        const SizedBox(height: 14),
        const _DashboardRevenueCard(),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _DashboardSmallMetricCard(title: 'Orders', value: '0'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _DashboardSmallMetricCard(title: 'Customers', value: '0'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD9E1EE)),
          ),
          child: Column(
            children: [
              const _DashboardEmptyVisual(),
              const SizedBox(height: 14),
              const Text(
                'No sales data yet',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your sales performance will appear here\nonce you record your first transaction.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: onCreateSale,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF007AFF),
                      size: 22,
                    ),
                  ),
                  label: const Text(
                    'Record Your First Sale',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardEmptyHeader extends StatelessWidget {
  const _DashboardEmptyHeader({required this.onNotification});

  final VoidCallback onNotification;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: Color(0xFFF4DCCB),
          child: Icon(Icons.person, color: Color(0xFF94A3B8)),
        ),
        const Spacer(),
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 42 / 2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: NotificationService.unreadCount,
          builder: (context, unreadCount, _) {
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onNotification,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications,
                        color: Color(0xFF475569),
                        size: 32,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardRevenueCard extends StatelessWidget {
  const _DashboardRevenueCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E1EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: Color(0xFF007AFF), size: 28),
              SizedBox(width: 10),
              Text(
                'Total Revenue',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 21),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _homeFormatAmount(0),
            style: const TextStyle(
              fontSize: 44 / 2,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSmallMetricCard extends StatelessWidget {
  const _DashboardSmallMetricCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E1EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 21),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 40 / 2,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardEmptyVisual extends StatelessWidget {
  const _DashboardEmptyVisual();

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFC9D6E8);
    const iconColor = Color(0xFFDCE4EF);
    return CustomPaint(
      painter: _DashedRoundedRectPainter(
        color: borderColor,
        radius: 16,
        strokeWidth: 1.4,
        dash: 7,
        gap: 6,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 230,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.show_chart_rounded, size: 70, color: iconColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _EmptyBar(height: 44),
                  SizedBox(width: 8),
                  _EmptyBar(height: 72),
                  SizedBox(width: 8),
                  _EmptyBar(height: 30),
                  SizedBox(width: 8),
                  _EmptyBar(height: 58),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBar extends StatelessWidget {
  const _EmptyBar({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE4EF),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.deltaText,
  });

  final String title;
  final String value;
  final String deltaText;
}

class _AutoMetricCards extends StatefulWidget {
  const _AutoMetricCards({required this.cards});

  final List<_MetricCardData> cards;

  @override
  State<_AutoMetricCards> createState() => _AutoMetricCardsState();
}

class _AutoMetricCardsState extends State<_AutoMetricCards> {
  static const _loopBasePage = 10000;
  static const _interval = Duration(seconds: 3);
  static const _duration = Duration(milliseconds: 900);

  late final PageController _controller;
  Timer? _timer;
  int _page = _loopBasePage;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: 0.81,
      initialPage: _loopBasePage,
    );
    _startLoop();
  }

  void _startLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_controller.hasClients || widget.cards.isEmpty) return;
      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) return;
      if (_isAnimating) return;
      _page += 1;
      _isAnimating = true;
      _controller
          .animateToPage(
            _page,
            duration: _duration,
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(() {
            if (mounted) {
              _isAnimating = false;
            }
          });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    return PageView.builder(
      controller: _controller,
      onPageChanged: (value) => _page = value,
      itemBuilder: (context, index) {
        final item = widget.cards[index % widget.cards.length];
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _MetricCard(
            title: item.title,
            value: item.value,
            deltaText: item.deltaText,
          ),
        );
      },
    );
  }
}

class _MainState extends StatelessWidget {
  const _MainState({
    required this.shop,
    required this.analytics,
    required this.sales,
    required this.trendTab,
    required this.onTabChanged,
    required this.onSettings,
    required this.onNotification,
    required this.onOpenSale,
  });

  final ShopProfile shop;
  final AnalyticsSummary analytics;
  final List<Sale> sales;
  final int trendTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSettings;
  final VoidCallback onNotification;
  final void Function(Sale) onOpenSale;

  @override
  Widget build(BuildContext context) {
    final trendBars = _buildTrendBars();
    final today = analytics.daily.isEmpty ? 0.0 : analytics.daily.first.total;
    final week = analytics.weekly.isEmpty ? 0.0 : analytics.weekly.first.total;
    final month = analytics.monthly.isEmpty
        ? 0.0
        : analytics.monthly.first.total;
    final todayPrev = analytics.daily.length > 1
        ? analytics.daily[1].total
        : 0.0;
    final weekPrev = analytics.weekly.length > 1
        ? analytics.weekly[1].total
        : 0.0;
    final monthPrev = analytics.monthly.length > 1
        ? analytics.monthly[1].total
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onSettings,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFDCE7F3),
                child: ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: (shop.logoUrl ?? '').trim().isEmpty
                        ? const Icon(Icons.store)
                        : Image(
                            image: MediaService.imageProvider(shop.logoUrl!)!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.store),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 34 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    (shop.address ?? '').trim().isEmpty
                        ? 'No address'
                        : shop.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: NotificationService.unreadCount,
              builder: (context, unreadCount, _) {
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onNotification,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Center(
                          child: Icon(
                            Icons.notifications,
                            color: Color(0xFF0F172A),
                            size: 28,
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 132,
          child: _AutoMetricCards(
            cards: [
              _MetricCardData(
                title: "TODAY'S SALES",
                value: _money(today),
                deltaText: _deltaText(today, todayPrev, 'yesterday'),
              ),
              _MetricCardData(
                title: 'THIS WEEK',
                value: _money(week),
                deltaText: _deltaText(week, weekPrev, 'last week'),
              ),
              _MetricCardData(
                title: 'THIS MONTH',
                value: _money(month),
                deltaText: _deltaText(month, monthPrev, 'last month'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              'Sales Trend',
              style: TextStyle(fontSize: 34 / 2, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _TrendPill(
                    label: 'Daily',
                    active: trendTab == 0,
                    onTap: () => onTabChanged(0),
                  ),
                  _TrendPill(
                    label: 'Weekly',
                    active: trendTab == 1,
                    onTap: () => onTabChanged(1),
                  ),
                  _TrendPill(
                    label: 'Monthly',
                    active: trendTab == 2,
                    onTap: () => onTabChanged(2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Bars(bars: trendBars),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                title: 'FAST MOVING',
                text: analytics.fastMoving.isEmpty
                    ? 'No data'
                    : analytics.fastMoving.first.productName,
                subtext: analytics.fastMoving.isEmpty
                    ? '0 sold in 30 days'
                    : '${analytics.fastMoving.first.sold30Days.toStringAsFixed(0)} sold in 30 days',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoCard(
                title: 'SLOW MOVING',
                text: analytics.slowMoving.isEmpty
                    ? 'No data'
                    : analytics.slowMoving.first.productName,
                subtext: analytics.slowMoving.isEmpty
                    ? '0 sold in 30 days'
                    : '${analytics.slowMoving.first.sold30Days.toStringAsFixed(0)} sold in 30 days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Recent Sales',
          style: TextStyle(fontSize: 34 / 2, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...sales
            .take(4)
            .map((s) => _SaleTile(sale: s, onTap: () => onOpenSale(s))),
      ],
    );
  }

  String _money(double value) => _homeFormatAmount(value);

  String _deltaText(double current, double previous, String period) {
    if (previous <= 0) return '+0.0% from $period';
    final delta = ((current - previous) / previous) * 100;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}% from $period';
  }

  List<_TrendBarPoint> _buildTrendBars() {
    if (trendTab == 0) return _buildDailyBars(analytics.daily);
    if (trendTab == 1) return _buildWeeklyBars(analytics.weekly);
    return _buildMonthlyBars(analytics.monthly);
  }

  List<_TrendBarPoint> _buildDailyBars(List<AnalyticsPoint> points) {
    final dataByPeriod = <String, AnalyticsPoint>{
      for (final p in points) p.period: p,
    };
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      final period = DateFormat('yyyy-MM-dd').format(day);
      return _TrendBarPoint(
        label: DateFormat('E').format(day),
        total: dataByPeriod[period]?.total ?? 0,
        units: dataByPeriod[period]?.units ?? 0,
      );
    });
  }

  List<_TrendBarPoint> _buildWeeklyBars(List<AnalyticsPoint> points) {
    final dataByPeriod = <String, AnalyticsPoint>{
      for (final p in points) p.period: p,
    };
    final now = DateTime.now();
    final currentWeekStart = _startOfIsoWeek(now);
    return List.generate(7, (index) {
      final weekStart = currentWeekStart.subtract(
        Duration(days: (6 - index) * 7),
      );
      final isoKey = _isoYearWeekKey(weekStart);
      return _TrendBarPoint(
        label: 'W${_isoWeekLabel(isoKey)}',
        total: dataByPeriod[isoKey]?.total ?? 0,
        units: dataByPeriod[isoKey]?.units ?? 0,
      );
    });
  }

  List<_TrendBarPoint> _buildMonthlyBars(List<AnalyticsPoint> points) {
    final dataByPeriod = <String, AnalyticsPoint>{
      for (final p in points) p.period: p,
    };
    final now = DateTime.now();
    return List.generate(7, (index) {
      final offset = 6 - index;
      final monthDate = DateTime(now.year, now.month - offset, 1);
      final key = DateFormat('yyyy-MM').format(monthDate);
      return _TrendBarPoint(
        label: _monthLabel(key),
        total: dataByPeriod[key]?.total ?? 0,
        units: dataByPeriod[key]?.units ?? 0,
      );
    });
  }

  String _isoWeekLabel(String period) {
    final parts = period.split('-');
    if (parts.length != 2) return period;
    return parts[1].padLeft(2, '0');
  }

  DateTime _startOfIsoWeek(DateTime day) {
    final weekday = day.weekday; // Mon=1..Sun=7
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: weekday - 1));
  }

  String _isoYearWeekKey(DateTime weekStart) {
    final thursday = weekStart.add(const Duration(days: 3));
    final isoYear = thursday.year;
    final firstThursday = _firstIsoThursday(isoYear);
    final week = 1 + (thursday.difference(firstThursday).inDays ~/ 7);
    return '$isoYear-${week.toString().padLeft(2, '0')}';
  }

  DateTime _firstIsoThursday(int isoYear) {
    final jan4 = DateTime(isoYear, 1, 4);
    final jan4Weekday = jan4.weekday; // Mon=1..Sun=7
    final jan4Thursday = jan4.add(Duration(days: 4 - jan4Weekday));
    return DateTime(jan4Thursday.year, jan4Thursday.month, jan4Thursday.day);
  }

  String _monthLabel(String period) {
    final parts = period.split('-');
    if (parts.length != 2) return period;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return period;
    return DateFormat('MMM').format(DateTime(year, month, 1));
  }
}

class _TrendBarPoint {
  const _TrendBarPoint({
    required this.label,
    required this.total,
    required this.units,
  });
  final String label;
  final double total;
  final double units;
}
