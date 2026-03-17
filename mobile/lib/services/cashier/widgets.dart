part of 'core.dart';

String _wrapChatText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final punctuated = normalized
      .replaceAll('/', '/\u200B')
      .replaceAll('-', '-\u200B')
      .replaceAll('_', '_\u200B')
      .replaceAll('.', '.\u200B')
      .replaceAll(',', ',\u200B')
      .replaceAll(':', ':\u200B');
  final tokenPattern = RegExp(r'(\S{18,})');
  return punctuated.replaceAllMapped(tokenPattern, (match) {
    final token = match.group(0) ?? '';
    if (token.isEmpty) {
      return token;
    }
    final buffer = StringBuffer();
    for (var index = 0; index < token.length; index++) {
      buffer.write(token[index]);
      final isBoundary = (index + 1) % 10 == 0 && index != token.length - 1;
      if (isBoundary) {
        buffer.write('\u200B');
      }
    }
    return buffer.toString();
  });
}

String _actionBubbleSignature(String text, bool busy) {
  final normalized = text.trim();
  final reconnectPrefix = 'Disconnected. Reconnecting in ';
  if (normalized.startsWith(reconnectPrefix) ||
      normalized == 'Disconnected. Reconnecting...') {
    return 'action:reconnect:$busy';
  }
  return 'action:$normalized:$busy';
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.controller, required this.status});

  final AnimationController controller;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _VoiceOrb(controller: controller),
        const SizedBox(height: 28),
        const SizedBox(height: 10),
        Text(
          status,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.controller,
    required this.recording,
    required this.responding,
    required this.status,
    required this.toolBusy,
    required this.toolStatus,
    required this.transcriptEntries,
    required this.currentUserTranscript,
    required this.currentModelTranscript,
  });

  final AnimationController controller;
  final bool recording;
  final bool responding;
  final String status;
  final bool toolBusy;
  final String? toolStatus;
  final List<_TranscriptEntry> transcriptEntries;
  final String? currentUserTranscript;
  final String? currentModelTranscript;

  @override
  Widget build(BuildContext context) {
    final actionSignature = toolStatus == null || toolStatus!.trim().isEmpty
        ? null
        : _actionBubbleSignature(toolStatus!, toolBusy);
    final bubbles = <Widget>[
      for (final entry in transcriptEntries)
        switch (entry.type) {
          _TranscriptEntryType.message => _ChatBubble(
            key: ValueKey<String>(entry.signature),
            speaker: entry.message!.speaker,
            text: entry.message!.text,
          ),
          _TranscriptEntryType.card => _ResponseTemplateBubble(
            key: ValueKey<String>(entry.signature),
            card: entry.card!,
          ),
        },
      if ((currentUserTranscript ?? '').trim().isNotEmpty)
        _ChatBubble(
          key: const ValueKey<String>('user_pending'),
          speaker: _TranscriptSpeaker.user,
          text: currentUserTranscript!,
          pending: true,
        ),
      if (toolStatus != null && toolStatus!.trim().isNotEmpty)
        _ActionBubble(
          key: ValueKey<String>(actionSignature!),
          text: toolStatus!,
          busy: toolBusy,
          controller: controller,
        ),
      if ((currentModelTranscript ?? '').trim().isNotEmpty)
        _ChatBubble(
          key: const ValueKey<String>('assistant_pending'),
          speaker: _TranscriptSpeaker.assistant,
          text: currentModelTranscript!,
          pending: true,
        ),
    ];
    final structureSignature = <String>[
      for (final entry in transcriptEntries) entry.signature,
      if ((currentUserTranscript ?? '').trim().isNotEmpty) 'user_pending',
      ?actionSignature,
      if ((currentModelTranscript ?? '').trim().isNotEmpty) 'assistant_pending',
    ].join('\n');
    final scrollSignature = <String>[
      for (final entry in transcriptEntries) entry.signature,
      if ((currentUserTranscript ?? '').trim().isNotEmpty)
        'user_pending:${currentUserTranscript!.trim()}',
      ?actionSignature,
      if ((currentModelTranscript ?? '').trim().isNotEmpty)
        'assistant_pending:${currentModelTranscript!.trim()}',
    ].join('\n');

    return _TranscriptPanel(
      bubbles: bubbles,
      structureSignature: structureSignature,
      scrollSignature: scrollSignature,
      emptyStateText: status,
    );
  }
}

class _TranscriptPanel extends StatefulWidget {
  const _TranscriptPanel({
    required this.bubbles,
    required this.structureSignature,
    required this.scrollSignature,
    required this.emptyStateText,
  });

  final List<Widget> bubbles;
  final String structureSignature;
  final String scrollSignature;
  final String emptyStateText;

  @override
  State<_TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends State<_TranscriptPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleAutoScroll(jump: true);
  }

  @override
  void didUpdateWidget(covariant _TranscriptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final structureChanged =
        oldWidget.structureSignature != widget.structureSignature;
    final scrollChanged = oldWidget.scrollSignature != widget.scrollSignature;
    if (structureChanged) {
      _scheduleAutoScroll();
      return;
    }
    if (scrollChanged) {
      _scheduleAutoScroll(jump: true);
    }
  }

  void _scheduleAutoScroll({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
        return;
      }
      try {
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.bubbles.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                widget.emptyStateText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            itemBuilder: (context, index) {
              final bubble = widget.bubbles[index];
              return _BubbleReveal(
                key: ValueKey<String>(
                  'reveal:${bubble.key ?? 'bubble-$index'}',
                ),
                child: bubble,
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: widget.bubbles.length,
          ),
      ],
    );
  }
}

class _BubbleReveal extends StatefulWidget {
  const _BubbleReveal({super.key, required this.child});

  final Widget child;

  @override
  State<_BubbleReveal> createState() => _BubbleRevealState();
}

class _BubbleRevealState extends State<_BubbleReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _scale = Tween<double>(begin: 0.97, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: const Color(0x14EF4444),
            borderRadius: BorderRadius.circular(52),
          ),
          child: const Icon(
            Icons.mic_off_rounded,
            color: Color(0xFFDC2626),
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Live cashier unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: retrying
              ? null
              : () {
                  unawaited(HapticFeedback.lightImpact());
                  unawaited(onRetry());
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            minimumSize: const Size(140, 48),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: retrying
                ? const Row(
                    key: ValueKey<String>('retrying'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Retrying...'),
                    ],
                  )
                : const Text('Retry', key: ValueKey<String>('retry')),
          ),
        ),
      ],
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1 + (controller.value * 0.08);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: const [
                  Color(0xFFFFFFFF),
                  Color(0xFFBFD5FF),
                  Color(0xFF6EA8FF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x33007AFF),
                  blurRadius: 34 + (controller.value * 10),
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 108,
                height: 108,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xDDFFFFFF),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 48,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    super.key,
    required this.speaker,
    required this.text,
    this.pending = false,
  });

  final _TranscriptSpeaker speaker;
  final String text;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final isUser = speaker == _TranscriptSpeaker.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF2563EB) : const Color(0xF7FFFFFF),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(24),
              topRight: const Radius.circular(24),
              bottomLeft: Radius.circular(isUser ? 24 : 10),
              bottomRight: Radius.circular(isUser ? 10 : 24),
            ),
            border: Border.all(
              color: isUser ? const Color(0x332563EB) : const Color(0x66FFFFFF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'YOU' : 'GEMINI',
                style: TextStyle(
                  color: isUser
                      ? const Color(0xCCFFFFFF)
                      : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _wrapChatText(text),
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
                softWrap: true,
              ),
              if (pending) ...[
                const SizedBox(height: 10),
                _PendingDots(light: isUser),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBubble extends StatelessWidget {
  const _ActionBubble({
    super.key,
    required this.text,
    required this.busy,
    required this.controller,
  });

  final String text;
  final bool busy;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse = busy ? (controller.value * 0.05) : 0.0;
        return Transform.scale(scale: 1 + pulse, child: child);
      },
      child: Align(
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xE6F8FAFC),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD6E0EA)),
            boxShadow: busy
                ? const [
                    BoxShadow(
                      color: Color(0x1438BDF8),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                busy
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: const Color(0xFF475569),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _wrapChatText(text),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 10),
                _BusyDots(controller: controller),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDots extends StatefulWidget {
  const _PendingDots({required this.light});

  final bool light;

  @override
  State<_PendingDots> createState() => _PendingDotsState();
}

class _PendingDotsState extends State<_PendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.light
        ? const Color(0xCCFFFFFF)
        : const Color(0xFF94A3B8);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (index) {
            final phase = (_controller.value + (index * 0.18)) % 1.0;
            final emphasis = 1 - ((phase - 0.5).abs() * 2);
            final opacity = 0.28 + (emphasis.clamp(0, 1) * 0.72);
            return Container(
              width: 6,
              height: 6,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _BusyDots extends StatelessWidget {
  const _BusyDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (index) {
            final phase = (controller.value + (index * 0.22)) % 1.0;
            final emphasis = 1 - ((phase - 0.5).abs() * 2);
            final opacity = 0.25 + (emphasis.clamp(0, 1) * 0.75);
            return Container(
              width: 5,
              height: 5,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 4),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

