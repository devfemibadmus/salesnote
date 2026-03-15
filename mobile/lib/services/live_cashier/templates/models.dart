part of '../../live_cashier.dart';

enum _TranscriptEntryType { message, card }

enum _TemplateKind { list, draft, saleReport, forecast, trend }

class _TranscriptEntry {
  const _TranscriptEntry.message(this.message)
    : type = _TranscriptEntryType.message,
      card = null;

  const _TranscriptEntry.card(this.card)
    : type = _TranscriptEntryType.card,
      message = null;

  final _TranscriptEntryType type;
  final _TranscriptMessage? message;
  final _TemplateCardData? card;

  String get signature {
    switch (type) {
      case _TranscriptEntryType.message:
        final entry = message!;
        return 'message:${entry.speaker.index}:${entry.text.trim()}';
      case _TranscriptEntryType.card:
        return 'card:${card!.signature}';
    }
  }
}

class _TemplateMetric {
  const _TemplateMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _TemplateRow {
  const _TemplateRow({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final String? trailing;
}

class _TemplateCardData {
  const _TemplateCardData({
    required this.kind,
    required this.signature,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.badges = const <String>[],
    this.metrics = const <_TemplateMetric>[],
    this.rows = const <_TemplateRow>[],
    this.footer,
  });

  final _TemplateKind kind;
  final String signature;
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<String> badges;
  final List<_TemplateMetric> metrics;
  final List<_TemplateRow> rows;
  final String? footer;
}
