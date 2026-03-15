part of '../live_cashier.dart';

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
    required this.muted,
    required this.responding,
    required this.status,
    required this.capturingPhoto,
    required this.toolBusy,
    required this.toolStatus,
    required this.transcriptEntries,
    required this.currentUserTranscript,
    required this.currentModelTranscript,
    required this.onTakePhoto,
  });

  final AnimationController controller;
  final bool recording;
  final bool muted;
  final bool responding;
  final String status;
  final bool capturingPhoto;
  final bool toolBusy;
  final String? toolStatus;
  final List<_TranscriptEntry> transcriptEntries;
  final String? currentUserTranscript;
  final String? currentModelTranscript;
  final Future<void> Function() onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final bubbles = <Widget>[
      for (final entry in transcriptEntries)
        switch (entry.type) {
          _TranscriptEntryType.message => _ChatBubble(
            speaker: entry.message!.speaker,
            text: entry.message!.text,
          ),
          _TranscriptEntryType.card => _ResponseTemplateBubble(
            card: entry.card!,
          ),
        },
      if (toolStatus != null && toolStatus!.trim().isNotEmpty)
        _ActionBubble(text: toolStatus!, busy: toolBusy),
      if ((currentModelTranscript ?? '').trim().isNotEmpty)
        _ChatBubble(
          speaker: _TranscriptSpeaker.assistant,
          text: currentModelTranscript!,
          pending: true,
        ),
      if ((currentUserTranscript ?? '').trim().isNotEmpty)
        _ChatBubble(
          speaker: _TranscriptSpeaker.user,
          text: currentUserTranscript!,
          pending: true,
        ),
    ];
    final contentSignature = <String>[
      for (final entry in transcriptEntries) entry.signature,
      if (toolStatus != null && toolStatus!.trim().isNotEmpty)
        'action:${toolStatus!.trim()}:$toolBusy',
      if ((currentModelTranscript ?? '').trim().isNotEmpty)
        'assistant_pending:${currentModelTranscript!.trim()}',
      if ((currentUserTranscript ?? '').trim().isNotEmpty)
        'user_pending:${currentUserTranscript!.trim()}',
    ].join('\n');

    return Column(
      children: [
        const SizedBox(height: 8),
        _VoiceOrb(
          controller: controller,
          active: responding || (recording && !muted),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: _TranscriptPanel(
            bubbles: bubbles,
            contentSignature: contentSignature,
            emptyStateText: status,
          ),
        ),
      ],
    );
  }
}

class _TranscriptPanel extends StatefulWidget {
  const _TranscriptPanel({
    required this.bubbles,
    required this.contentSignature,
    required this.emptyStateText,
  });

  final List<Widget> bubbles;
  final String contentSignature;
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
    if (oldWidget.contentSignature != widget.contentSignature) {
      _scheduleAutoScroll();
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
    final panelRadius = BorderRadius.circular(30);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xB8FFFFFF),
        borderRadius: panelRadius,
        border: Border.all(color: const Color(0x88FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: panelRadius,
        child: Stack(
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
                itemBuilder: (context, index) => widget.bubbles[index],
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemCount: widget.bubbles.length,
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xF7FFFFFF),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 38,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFFFFFFFF),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            minimumSize: const Size(140, 48),
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  const _VoiceOrb({required this.controller, this.active = false});

  final AnimationController controller;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1 + (controller.value * (active ? 0.12 : 0.08));
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: active
                    ? const [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFD4D4),
                        Color(0xFFF87171),
                      ]
                    : const [
                        Color(0xFFFFFFFF),
                        Color(0xFFBFD5FF),
                        Color(0xFF6EA8FF),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? const Color(0x33EF4444)
                      : const Color(0x33007AFF),
                  blurRadius: 34 + (controller.value * (active ? 16 : 10)),
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
                child: Icon(
                  active ? Icons.mic_rounded : Icons.graphic_eq_rounded,
                  size: 48,
                  color: active
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
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
                text.trim(),
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              if (pending) ...[
                const SizedBox(height: 10),
                Text(
                  'typing...',
                  style: TextStyle(
                    color: isUser
                        ? const Color(0xCCFFFFFF)
                        : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _ActionBubble extends StatelessWidget {
  const _ActionBubble({required this.text, required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xE6F8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD6E0EA)),
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
                text.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x99FFFFFF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
        ),
      ),
    );
  }
}
