part of '../core.dart';

class _ResponseTemplateBubble extends StatelessWidget {
  const _ResponseTemplateBubble({super.key, required this.card});

  final _TemplateCardData card;

  @override
  Widget build(BuildContext context) {
    final tone = _templateTone(card.kind);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[tone.backgroundTop, tone.backgroundBottom],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: tone.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: tone.shadow,
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tone.iconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tone.icon, color: tone.iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          card.eyebrow ?? _templateKindLabel(card.kind),
                          style: TextStyle(
                            color: tone.eyebrow,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((card.subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  card.subtitle!.trim(),
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
              if (card.badges.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final badge in card.badges)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: tone.badgeBackground,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: tone.badgeBorder),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: tone.badgeText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (card.metrics.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final metric in card.metrics)
                      Container(
                        width: 148,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFAFFFFFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: tone.metricBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              metric.value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              metric.label,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (card.rows.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xCCFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tone.rowBorder),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (
                        var index = 0;
                        index < card.rows.length;
                        index++
                      ) ...<Widget>[
                        if (index > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: tone.rowDivider,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      card.rows[index].title,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                    if ((card.rows[index].subtitle ?? '')
                                        .trim()
                                        .isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 4),
                                      Text(
                                        card.rows[index].subtitle!.trim(),
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if ((card.rows[index].trailing ?? '')
                                  .trim()
                                  .isNotEmpty) ...<Widget>[
                                const SizedBox(width: 12),
                                Text(
                                  card.rows[index].trailing!.trim(),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: tone.trailing,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if ((card.footer ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  card.footer!.trim(),
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateTone {
  const _TemplateTone({
    required this.icon,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.border,
    required this.shadow,
    required this.iconBackground,
    required this.iconColor,
    required this.eyebrow,
    required this.badgeBackground,
    required this.badgeBorder,
    required this.badgeText,
    required this.metricBorder,
    required this.rowBorder,
    required this.rowDivider,
    required this.trailing,
  });

  final IconData icon;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color border;
  final Color shadow;
  final Color iconBackground;
  final Color iconColor;
  final Color eyebrow;
  final Color badgeBackground;
  final Color badgeBorder;
  final Color badgeText;
  final Color metricBorder;
  final Color rowBorder;
  final Color rowDivider;
  final Color trailing;
}

_TemplateTone _templateTone(_TemplateKind kind) {
  switch (kind) {
    case _TemplateKind.list:
      return const _TemplateTone(
        icon: Icons.format_list_bulleted_rounded,
        backgroundTop: Color(0xFFFFFBEB),
        backgroundBottom: Color(0xFFFFF1D6),
        border: Color(0xFFF5D7A1),
        shadow: Color(0x14B45309),
        iconBackground: Color(0xFFFFE8B5),
        iconColor: Color(0xFFB45309),
        eyebrow: Color(0xFF92400E),
        badgeBackground: Color(0xFFFFF6DC),
        badgeBorder: Color(0xFFF6D28E),
        badgeText: Color(0xFF92400E),
        metricBorder: Color(0xFFF6D28E),
        rowBorder: Color(0xFFF7E5BA),
        rowDivider: Color(0xFFF7E5BA),
        trailing: Color(0xFFB45309),
      );
    case _TemplateKind.draft:
      return const _TemplateTone(
        icon: Icons.receipt_long_rounded,
        backgroundTop: Color(0xFFFFF7ED),
        backgroundBottom: Color(0xFFFFE8D2),
        border: Color(0xFFF7C89B),
        shadow: Color(0x14C2410C),
        iconBackground: Color(0xFFFFD8B0),
        iconColor: Color(0xFFC2410C),
        eyebrow: Color(0xFF9A3412),
        badgeBackground: Color(0xFFFFEAD7),
        badgeBorder: Color(0xFFF7C89B),
        badgeText: Color(0xFF9A3412),
        metricBorder: Color(0xFFF7C89B),
        rowBorder: Color(0xFFF7D9B7),
        rowDivider: Color(0xFFF7D9B7),
        trailing: Color(0xFFC2410C),
      );
    case _TemplateKind.saleReport:
      return const _TemplateTone(
        icon: Icons.assessment_rounded,
        backgroundTop: Color(0xFFECFDF5),
        backgroundBottom: Color(0xFFDDF7EB),
        border: Color(0xFFB9E8CF),
        shadow: Color(0x1415803D),
        iconBackground: Color(0xFFCFF4DF),
        iconColor: Color(0xFF15803D),
        eyebrow: Color(0xFF166534),
        badgeBackground: Color(0xFFE8FAF0),
        badgeBorder: Color(0xFFB9E8CF),
        badgeText: Color(0xFF166534),
        metricBorder: Color(0xFFB9E8CF),
        rowBorder: Color(0xFFD7F2E3),
        rowDivider: Color(0xFFD7F2E3),
        trailing: Color(0xFF15803D),
      );
    case _TemplateKind.forecast:
      return const _TemplateTone(
        icon: Icons.auto_graph_rounded,
        backgroundTop: Color(0xFFEFF6FF),
        backgroundBottom: Color(0xFFDCEBFF),
        border: Color(0xFFB9D6FF),
        shadow: Color(0x141D4ED8),
        iconBackground: Color(0xFFD6E6FF),
        iconColor: Color(0xFF1D4ED8),
        eyebrow: Color(0xFF1E40AF),
        badgeBackground: Color(0xFFE7F0FF),
        badgeBorder: Color(0xFFB9D6FF),
        badgeText: Color(0xFF1E40AF),
        metricBorder: Color(0xFFB9D6FF),
        rowBorder: Color(0xFFD5E6FF),
        rowDivider: Color(0xFFD5E6FF),
        trailing: Color(0xFF1D4ED8),
      );
    case _TemplateKind.trend:
      return const _TemplateTone(
        icon: Icons.show_chart_rounded,
        backgroundTop: Color(0xFFFFF1F2),
        backgroundBottom: Color(0xFFFFE2E2),
        border: Color(0xFFF7C2C7),
        shadow: Color(0x14BE123C),
        iconBackground: Color(0xFFFFD4DA),
        iconColor: Color(0xFFBE123C),
        eyebrow: Color(0xFF9F1239),
        badgeBackground: Color(0xFFFFE7EB),
        badgeBorder: Color(0xFFF7C2C7),
        badgeText: Color(0xFF9F1239),
        metricBorder: Color(0xFFF7C2C7),
        rowBorder: Color(0xFFF7D7DB),
        rowDivider: Color(0xFFF7D7DB),
        trailing: Color(0xFFBE123C),
      );
  }
}

String _templateKindLabel(_TemplateKind kind) {
  switch (kind) {
    case _TemplateKind.list:
      return 'LIST';
    case _TemplateKind.draft:
      return 'DRAFT';
    case _TemplateKind.saleReport:
      return 'REPORT';
    case _TemplateKind.forecast:
      return 'FORECAST';
    case _TemplateKind.trend:
      return 'TREND';
  }
}
