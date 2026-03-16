part of 'core.dart';

enum _TranscriptSpeaker { user, assistant }

enum _PanelDockSide { left, right }

class _TranscriptMessage {
  const _TranscriptMessage({required this.speaker, required this.text});

  final _TranscriptSpeaker speaker;
  final String text;
}

class _LiveCashierOverlay extends StatefulWidget {
  const _LiveCashierOverlay({super.key});

  @override
  State<_LiveCashierOverlay> createState() => _LiveCashierOverlayState();
}

class _LiveCashierOverlayState extends State<_LiveCashierOverlay>
    with TickerProviderStateMixin {
  static const double _panelInset = 12;
  static const double _panelOvershoot = 28;
  final _api = ApiClient(TokenStore());
  final _recorder = AudioRecorder();
  final _player = fs.FlutterSoundPlayer();
  late final AnimationController _pulseController;
  late final AnimationController _panelSpringController;
  WebSocket? _socket;
  StreamSubscription<Uint8List>? _recordingSub;
  String? _error;
  bool _loading = true;
  bool _connected = false;
  bool _isRecording = false;
  bool _modelResponding = false;
  bool _setupReady = false;
  bool _openingGreetingSent = false;
  bool _toolBusy = false;
  int _audioChunkLogCount = 0;
  String _status = 'Bootstrapping live session...';
  String? _toolStatus;
  final List<_TranscriptEntry> _transcriptEntries = <_TranscriptEntry>[];
  final List<_TemplateCardData> _pendingTemplateCards = <_TemplateCardData>[];
  String? _currentUserTranscript;
  String? _currentModelTranscript;
  bool _draftIsInvoice = false;
  String? _draftCacheId;
  String? _draftCustomerName;
  String? _draftCustomerContact;
  final List<LiveAgentDraftItem> _draftItems = <LiveAgentDraftItem>[];
  String? _draftSignatureId;
  String? _draftBankAccountId;
  double _draftDiscountAmount = 0;
  double _draftVatAmount = 0;
  double _draftServiceFeeAmount = 0;
  double _draftDeliveryFeeAmount = 0;
  double _draftRoundingAmount = 0;
  double _draftOtherAmount = 0;
  String _draftOtherLabel = 'Others';
  String? _lastPersistedDraftSnapshot;
  String? _pendingRoute;
  Object? _pendingArgs;
  Future<void> Function()? _pendingPostCloseAction;
  bool _closeAfterToolResponse = false;
  Future<void> _audioQueue = Future<void>.value();
  int _audioEpoch = 0;
  final BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  bool _turnFinalizing = false;
  bool _playerReady = false;
  bool _playerStarted = false;
  int _playerSampleRate = 24000;
  bool _playerDisposed = false;
  Future<void>? _playerInitFuture;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  int _reconnectSecondsRemaining = 0;
  bool _reconnecting = false;
  bool _closingOverlay = false;
  bool _awaitingTurnCompletion = false;
  bool _retryingBootstrap = false;
  String? _pendingReplayUserText;
  Map<String, dynamic>? _pendingToolResponsePayload;
  List<Map<String, dynamic>>? _pendingToolIntent;
  String? _pendingToolIntentLabel;
  bool _pendingNonReplayableToolIntent = false;
  Future<void> _actionHistoryQueue = Future<void>.value();
  final Map<String, _SalesWindowCacheEntry> _salesWindowCache =
      <String, _SalesWindowCacheEntry>{};
  bool _liveAudioSessionConfigured = false;
  Future<void>? _liveAudioSessionFuture;
  bool _panelExpanded = false;
  double? _panelLeft;
  double? _panelTop;
  Animation<double>? _panelLeftAnimation;
  Animation<double>? _panelTopAnimation;

  @override
  void initState() {
    super.initState();
    unawaited(_configurePlayer());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _panelSpringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
      if (!mounted) return;
      if (_panelLeftAnimation == null || _panelTopAnimation == null) {
        return;
      }
      setState(() {
        _panelLeft = _panelLeftAnimation!.value;
        _panelTop = _panelTopAnimation!.value;
      });
    });
    _bootstrap();
  }

  void _log(String message) {
    debugPrint('LIVE CASHIER: $message');
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _expandPanel() {
    if (!mounted || _panelExpanded) return;
    _safeSetState(() => _panelExpanded = true);
  }

  void _togglePanel() {
    if (!mounted) return;
    _safeSetState(() => _panelExpanded = !_panelExpanded);
  }

  ({double minLeft, double maxLeft, double minTop, double maxTop}) _panelBounds({
    required Size screenSize,
    required EdgeInsets padding,
    required double panelWidth,
    required double panelHeight,
  }) {
    final minLeft = _panelInset;
    final maxLeft = math.max(minLeft, screenSize.width - panelWidth - _panelInset);
    final minTop = padding.top + _panelInset;
    final maxTop = math.max(
      minTop,
      screenSize.height - panelHeight - padding.bottom - _panelInset,
    );
    return (
      minLeft: minLeft,
      maxLeft: maxLeft,
      minTop: minTop,
      maxTop: maxTop,
    );
  }

  void _stopPanelSpring() {
    if (_panelSpringController.isAnimating) {
      _panelSpringController.stop();
    }
    _panelLeftAnimation = null;
    _panelTopAnimation = null;
  }

  void _dragPanel({
    required DragUpdateDetails details,
    required Size screenSize,
    required EdgeInsets padding,
    required double panelWidth,
    required double panelHeight,
  }) {
    _stopPanelSpring();
    final bounds = _panelBounds(
      screenSize: screenSize,
      padding: padding,
      panelWidth: panelWidth,
      panelHeight: panelHeight,
    );
    final defaultLeft = (screenSize.width - panelWidth) / 2;
    final defaultTop = screenSize.height - panelHeight - padding.bottom - 88;
    _safeSetState(() {
      _panelLeft = ((_panelLeft ?? defaultLeft) + details.delta.dx).clamp(
        bounds.minLeft - _panelOvershoot,
        bounds.maxLeft + _panelOvershoot,
      );
      _panelTop = ((_panelTop ?? defaultTop) + details.delta.dy).clamp(
        bounds.minTop - _panelOvershoot,
        bounds.maxTop + _panelOvershoot,
      );
    });
  }

  void _settlePanel({
    required Size screenSize,
    required EdgeInsets padding,
    required double panelWidth,
    required double panelHeight,
  }) {
    final bounds = _panelBounds(
      screenSize: screenSize,
      padding: padding,
      panelWidth: panelWidth,
      panelHeight: panelHeight,
    );
    final defaultLeft = (screenSize.width - panelWidth) / 2;
    final defaultTop = screenSize.height - panelHeight - padding.bottom - 88;
    final startLeft = _panelLeft ?? defaultLeft;
    final startTop = _panelTop ?? defaultTop;
    final targetLeft = startLeft.clamp(bounds.minLeft, bounds.maxLeft).toDouble();
    final targetTop = startTop.clamp(bounds.minTop, bounds.maxTop).toDouble();
    if ((startLeft - targetLeft).abs() < 0.5 && (startTop - targetTop).abs() < 0.5) {
      _panelLeft = targetLeft;
      _panelTop = targetTop;
      return;
    }
    _panelLeftAnimation = Tween<double>(
      begin: startLeft,
      end: targetLeft,
    ).animate(
      CurvedAnimation(parent: _panelSpringController, curve: Curves.elasticOut),
    );
    _panelTopAnimation = Tween<double>(
      begin: startTop,
      end: targetTop,
    ).animate(
      CurvedAnimation(parent: _panelSpringController, curve: Curves.elasticOut),
    );
    _panelSpringController
      ..reset()
      ..forward();
  }

  void _appendTranscriptMessage(_TranscriptSpeaker speaker, String? text) {
    final normalized = (text ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }
    final previous = _transcriptEntries.isEmpty
        ? null
        : _transcriptEntries.last;
    if (previous != null &&
        previous.type == _TranscriptEntryType.message &&
        previous.message!.speaker == speaker &&
        previous.message!.text.trim() == normalized) {
      return;
    }
    _transcriptEntries.add(
      _TranscriptEntry.message(
        _TranscriptMessage(speaker: speaker, text: normalized),
      ),
    );
  }

  void _appendTemplateCard(_TemplateCardData? card) {
    if (card == null) {
      return;
    }
    final previous = _transcriptEntries.isEmpty
        ? null
        : _transcriptEntries.last;
    if (previous != null &&
        previous.type == _TranscriptEntryType.card &&
        previous.card!.signature == card.signature) {
      return;
    }
    _transcriptEntries.add(_TranscriptEntry.card(card));
  }

  void _queueTemplateCard(_TemplateCardData? card) {
    if (card == null) {
      return;
    }
    if (_pendingTemplateCards.any(
      (entry) => entry.signature == card.signature,
    )) {
      return;
    }
    _pendingTemplateCards.add(card);
  }

  @override
  void dispose() {
    _closingOverlay = true;
    _reconnectTimer?.cancel();
    _reconnectSecondsRemaining = 0;
    _recordingSub?.cancel();
    _socket?.close();
    _playerDisposed = true;
    unawaited(_stopPlayerStream(forceStop: true));
    unawaited(_player.closePlayer());
    _recorder.dispose();
    _pulseController.dispose();
    _panelSpringController.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compactPanelWidth = math.min(media.size.width - 24, 360.0);
    final expandedPanelWidth = compactPanelWidth;
    final collapsedHeight = 72.0;
    final expandedHeight = math.min(media.size.height * 0.66, 520.0);
    final panelHeight = _panelExpanded ? expandedHeight : collapsedHeight;
    final panelWidthBase = _panelExpanded ? expandedPanelWidth : compactPanelWidth;
    final defaultPanelLeft = (media.size.width - panelWidthBase) / 2;
    final defaultPanelTop =
        media.size.height - panelHeight - media.padding.bottom - 88;
    final panelBounds = _panelBounds(
      screenSize: media.size,
      padding: media.padding,
      panelWidth: panelWidthBase,
      panelHeight: panelHeight,
    );
    final rawPanelLeft = (_panelLeft ?? defaultPanelLeft).clamp(
      panelBounds.minLeft,
      panelBounds.maxLeft,
    ).toDouble();
    final panelTop = (_panelTop ?? defaultPanelTop).clamp(
      panelBounds.minTop,
      panelBounds.maxTop,
    ).toDouble();
    final panelDockSide = rawPanelLeft < defaultPanelLeft
        ? _PanelDockSide.left
        : _PanelDockSide.right;
    final distanceFromCenter = (rawPanelLeft - defaultPanelLeft).abs();
    final maxTravelToEdge = panelDockSide == _PanelDockSide.left
        ? (defaultPanelLeft - panelBounds.minLeft)
        : (panelBounds.maxLeft - defaultPanelLeft);
    final normalizedTravel = maxTravelToEdge <= 0
        ? 0.0
        : (distanceFromCenter / maxTravelToEdge).clamp(0.0, 1.0);
    const dockStart = 0.55;
    final dockFraction = _panelExpanded
        ? 0.0
        : ((normalizedTravel - dockStart) / (1 - dockStart)).clamp(0.0, 1.0);
    final collapsedDockWidth = 72.0;
    final activePanelWidth = _panelExpanded
        ? expandedPanelWidth
        : compactPanelWidth -
            ((compactPanelWidth - collapsedDockWidth) * dockFraction);
    final targetDockLeft = panelDockSide == _PanelDockSide.left
        ? panelBounds.minLeft
        : media.size.width - activePanelWidth - _panelInset;
    final panelLeft = _panelExpanded
        ? rawPanelLeft
        : rawPanelLeft + ((targetDockLeft - rawPanelLeft) * dockFraction);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: panelLeft,
          top: panelTop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: activePanelWidth,
            height: panelHeight,
            decoration: BoxDecoration(
              color: const Color(0xF7FFFFFF),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFD6E2F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F172A),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showExpandedContent =
                      _panelExpanded && constraints.maxHeight >= 140;
                  return showExpandedContent
                      ? Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (_) => _stopPanelSpring(),
                              onPanUpdate: (details) => _dragPanel(
                                details: details,
                                screenSize: media.size,
                                padding: media.padding,
                                panelWidth: expandedPanelWidth,
                                panelHeight: panelHeight,
                              ),
                              onPanEnd: (_) => _settlePanel(
                                screenSize: media.size,
                                padding: media.padding,
                                panelWidth: expandedPanelWidth,
                                panelHeight: panelHeight,
                              ),
                              child: _PersistentCashierHeader(
                                title: _error != null
                                    ? 'Live cashier unavailable'
                                    : (_loading
                                          ? 'Starting live cashier'
                                          : 'Live cashier'),
                                status: _currentStatus(),
                                onCollapse: _togglePanel,
                                onClose: _closeOverlay,
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  14,
                                  10,
                                ),
                                child: _loading
                                    ? _LoadingBody(
                                        controller: _pulseController,
                                        status: _status,
                                      )
                                    : _error != null
                                    ? _ErrorBody(
                                        message: _error!,
                                        retrying: _retryingBootstrap,
                                        onRetry: _retryBootstrap,
                                      )
                                    : _ReadyBody(
                                        controller: _pulseController,
                                        recording: _isRecording,
                                        responding: _modelResponding,
                                        status: _currentStatus(),
                                        toolBusy: _toolBusy,
                                        toolStatus: _toolStatus,
                                        transcriptEntries:
                                            List<_TranscriptEntry>.unmodifiable(
                                              _transcriptEntries,
                                            ),
                                        currentUserTranscript:
                                            _currentUserTranscript,
                                        currentModelTranscript:
                                            _currentModelTranscript,
                                      ),
                              ),
                            ),
                          ],
                        )
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (_) => _stopPanelSpring(),
                          onPanUpdate: (details) => _dragPanel(
                            details: details,
                            screenSize: media.size,
                            padding: media.padding,
                            panelWidth: compactPanelWidth,
                            panelHeight: panelHeight,
                          ),
                          onPanEnd: (_) => _settlePanel(
                            screenSize: media.size,
                            padding: media.padding,
                            panelWidth: compactPanelWidth,
                            panelHeight: panelHeight,
                          ),
                          child: _PersistentCashierCompact(
                            loading: _loading,
                            error: _error,
                            responding: _modelResponding,
                            toolBusy: _toolBusy,
                            status: _currentStatus(),
                            toolStatus: _toolStatus,
                            onExpand: _expandPanel,
                            onClose: _closeOverlay,
                            dockFraction: dockFraction,
                            dockSide: panelDockSide,
                          ),
                        );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersistentCashierHeader extends StatelessWidget {
  const _PersistentCashierHeader({
    required this.title,
    required this.status,
    required this.onCollapse,
    required this.onClose,
  });

  final String title;
  final String status;
  final VoidCallback onCollapse;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (status.trim().isNotEmpty)
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCollapse,
            icon: const Icon(Icons.remove_rounded),
            color: const Color(0xFF475569),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: const Color(0xFF475569),
          ),
        ],
      ),
    );
  }
}

class _PersistentCashierCompact extends StatelessWidget {
  const _PersistentCashierCompact({
    required this.loading,
    required this.error,
    required this.responding,
    required this.toolBusy,
    required this.status,
    required this.toolStatus,
    required this.onExpand,
    required this.onClose,
    required this.dockFraction,
    required this.dockSide,
  });

  final bool loading;
  final String? error;
  final bool responding;
  final bool toolBusy;
  final String status;
  final String? toolStatus;
  final VoidCallback onExpand;
  final VoidCallback onClose;
  final double dockFraction;
  final _PanelDockSide dockSide;

  @override
  Widget build(BuildContext context) {
    final badgeColor = error != null
        ? const Color(0xFFDC2626)
        : (responding ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    final summary = error ?? toolStatus ?? status;
    final contentVisible = dockFraction < 0.85;
    final textOpacity = (1 - (dockFraction * 1.6)).clamp(0.0, 1.0);
    final spinnerOpacity = (1 - (dockFraction * 2)).clamp(0.0, 1.0);
    final closeOpacity = (1 - (dockFraction * 2.4)).clamp(0.0, 1.0);
    final horizontalPadding = 14 - (6 * dockFraction);
    final iconLeftPadding = 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExpand,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: dockFraction > 0.92
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: dockSide == _PanelDockSide.right ? iconLeftPadding : 0,
                ),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    error != null
                        ? Icons.error_outline_rounded
                        : (responding
                              ? Icons.mic_rounded
                              : Icons.graphic_eq_rounded),
                    color: badgeColor,
                  ),
                ),
              ),
              if (contentVisible) ...[
                SizedBox(width: 12 * textOpacity),
                Expanded(
                  child: Opacity(
                    opacity: textOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live cashier running',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          summary.trim().isEmpty
                              ? (loading ? 'Starting...' : 'Tap to expand')
                              : summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (toolBusy || loading)
                  Opacity(
                    opacity: spinnerOpacity,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.1),
                    ),
                  ),
                IgnorePointer(
                  ignoring: closeOpacity == 0,
                  child: Opacity(
                    opacity: closeOpacity,
                    child: IconButton(
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ] else if (toolBusy || loading)
                IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: spinnerOpacity,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

