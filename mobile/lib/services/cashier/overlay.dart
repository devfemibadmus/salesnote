part of 'core.dart';

enum _TranscriptSpeaker { user, assistant }

Future<void> _triggerStrongTapHaptic() async {
  try {
    await HapticFeedback.heavyImpact();
  } catch (_) {}
  if (Platform.isAndroid) {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}

class _TranscriptMessage {
  const _TranscriptMessage({required this.speaker, required this.text});

  final _TranscriptSpeaker speaker;
  final String text;
}

class _LiveCashierOverlay extends StatefulWidget {
  const _LiveCashierOverlay();

  @override
  State<_LiveCashierOverlay> createState() => _LiveCashierOverlayState();
}

class _LiveCashierOverlayState extends State<_LiveCashierOverlay>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient(TokenStore());
  final _recorder = AudioRecorder();
  final _player = fs.FlutterSoundPlayer();
  late final AnimationController _pulseController;
  WebSocket? _socket;
  StreamSubscription<Uint8List>? _recordingSub;
  String? _error;
  bool _loading = true;
  bool _connected = false;
  bool _isRecording = false;
  bool _micMuted = false;
  bool _modelResponding = false;
  bool _setupReady = false;
  bool _openingGreetingSent = false;
  bool _openingGreetingPendingUnmute = false;
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

  @override
  void initState() {
    super.initState();
    unawaited(_configurePlayer());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bootstrap();
  }

  void _log(String message) {
    debugPrint('LIVE CASHIER: $message');
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
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
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF4F8FF),
                    Color(0xFFE8F0FF),
                    Color(0xFFDCE7FF),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      _CloseButton(onTap: _closeOverlay),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
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
                            muted: _micMuted,
                            responding: _modelResponding,
                            status: _currentStatus(),
                            toolBusy: _toolBusy,
                            toolStatus: _toolStatus,
                            transcriptEntries:
                                List<_TranscriptEntry>.unmodifiable(
                                  _transcriptEntries,
                                ),
                            currentUserTranscript: _currentUserTranscript,
                            currentModelTranscript: _currentModelTranscript,
                          ),
                  ),
                  const SizedBox(height: 18),
                  _loading || _error != null
                      ? const SizedBox()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LiveControlButton(
                              onTap: () => unawaited(_toggleMute()),
                              icon: _micMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              active: !_micMuted,
                            ),
                          ],
                        ),
                  SizedBox(height: media.padding.bottom > 0 ? 0 : 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveControlButton extends StatelessWidget {
  const _LiveControlButton({
    required this.onTap,
    required this.icon,
    required this.active,
  });

  final VoidCallback onTap;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _triggerStrongTapHaptic();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : const Color(0x99FFFFFF),
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? const Color(0x332563EB) : const Color(0x66FFFFFF),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 30,
          color: active ? Colors.white : const Color(0xFF2563EB),
        ),
      ),
    );
  }
}
