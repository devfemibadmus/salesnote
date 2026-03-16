part of '../core.dart';

extension _LiveCashierOverlaySocketReplay on _LiveCashierOverlayState {
  Future<void> _configurePlayer() async {
    if (_playerDisposed || _playerReady) {
      return;
    }
    final existing = _playerInitFuture;
    if (existing != null) {
      await existing;
      return;
    }
    final future = () async {
      await _player.openPlayer();
      _playerReady = true;
    }();
    _playerInitFuture = future;
    try {
      await future;
    } finally {
      if (identical(_playerInitFuture, future)) {
        _playerInitFuture = null;
      }
    }
  }

  Future<void> _ensurePlayerStarted(int sampleRate) async {
    if (!_playerReady) {
      await _configurePlayer();
    }
    if (_playerDisposed) {
      return;
    }
    if (_playerStarted && _playerSampleRate == sampleRate) {
      return;
    }
    if (_playerStarted) {
      try {
        await _player.stopPlayer();
      } catch (_) {}
      _playerStarted = false;
    }
    await _player.startPlayerFromStream(
      codec: fs.Codec.pcm16,
      interleaved: true,
      numChannels: 1,
      sampleRate: sampleRate,
      bufferSize: sampleRate,
    );
    _playerStarted = true;
    _playerSampleRate = sampleRate;
  }

  Future<void> _stopPlayerStream({bool forceStop = false}) async {
    _audioEpoch += 1;
    _audioQueue = Future<void>.value();
    _pcmBuffer.clear();
    if (forceStop && _playerStarted) {
      try {
        await _player.stopPlayer();
      } catch (_) {}
      _playerStarted = false;
    }
  }

  Future<void> _interruptCurrentModelOutput({required String reason}) async {
    if (_suppressCurrentModelOutput) {
      return;
    }
    _log('audio:barge-in reason=$reason');
    _suppressCurrentModelOutput = true;
    await _stopPlayerStream(forceStop: true);
    if (!mounted) {
      _currentModelTranscript = null;
      _modelResponding = false;
      return;
    }
    _safeSetState(() {
      _currentModelTranscript = null;
      _modelResponding = false;
      _status = _currentStatus();
    });
  }

  void _markTurnPending({String? replayText}) {
    _awaitingTurnCompletion = true;
    final normalizedReplayText = (replayText ?? '').trim();
    if (normalizedReplayText.isNotEmpty) {
      _pendingReplayUserText = normalizedReplayText;
    }
  }

  void _clearPendingTurnState() {
    _awaitingTurnCompletion = false;
    _suppressCurrentModelOutput = false;
    _pendingReplayUserText = null;
    _pendingToolResponsePayload = null;
    _pendingToolIntent = null;
    _pendingToolIntentLabel = null;
    _pendingNonReplayableToolIntent = false;
    _pendingTemplateCards.clear();
  }

  void _prepareInterruptedTurnForReplay({String? replayText}) {
    final normalizedReplayText = (replayText ?? '').trim();
    if (!mounted) {
      if ((_currentUserTranscript ?? '').trim().isEmpty &&
          normalizedReplayText.isNotEmpty) {
        _currentUserTranscript = normalizedReplayText;
      }
      _currentModelTranscript = null;
      _modelResponding = false;
      return;
    }
    _safeSetState(() {
      if ((_currentUserTranscript ?? '').trim().isEmpty &&
          normalizedReplayText.isNotEmpty) {
        _currentUserTranscript = normalizedReplayText;
      }
      _currentModelTranscript = null;
      _modelResponding = false;
      _status = _currentStatus();
    });
  }

  Future<void> _sendClientContentTurn(
    String text, {
    bool cacheForReplay = true,
  }) async {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      return;
    }
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (cacheForReplay) {
      _markTurnPending(replayText: normalized);
    }
    socket.add(
      jsonEncode({
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': normalized},
              ],
            },
          ],
          'turnComplete': true,
        },
      }),
    );
  }

  Future<void> _restorePendingTurnIfNeeded() async {
    if (!_awaitingTurnCompletion) {
      return;
    }
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      return;
    }
    if (_pendingToolResponsePayload != null) {
      _log('replay:toolResponse names=${_pendingToolIntentLabel ?? "-"}');
      try {
        _prepareInterruptedTurnForReplay();
        socket.add(jsonEncode(_pendingToolResponsePayload));
        if (mounted) {
          _safeSetState(() {
            _toolStatus = 'Restored interrupted action after reconnect.';
          });
        }
        return;
      } catch (e) {
        _log('replay:toolResponse:error $e');
      }
    }

    final replayableIntent = _pendingToolIntent;
    if (replayableIntent != null && replayableIntent.isNotEmpty) {
      _log('replay:toolIntent names=${_pendingToolIntentLabel ?? "-"}');
      _prepareInterruptedTurnForReplay();
      unawaited(_handleToolCalls(replayableIntent));
      return;
    }

    if (_pendingNonReplayableToolIntent) {
      _log(
        'replay:skip nonReplayableToolIntent names=${_pendingToolIntentLabel ?? "-"}',
      );
      _clearPendingTurnState();
      if (mounted) {
        _safeSetState(() {
          _toolStatus =
              'Reconnected. Repeat the last action to avoid duplicate changes.';
        });
      }
      return;
    }

    final replayText = (_pendingReplayUserText ?? '').trim();
    if (replayText.isNotEmpty) {
      _log('replay:userTurn text="$replayText"');
      _prepareInterruptedTurnForReplay(replayText: replayText);
      await _sendClientContentTurn(replayText, cacheForReplay: false);
      if (mounted) {
        _safeSetState(() {
          _toolStatus = 'Re-sent last question after reconnect.';
        });
      }
      return;
    }
  }

  Future<void> _finalizeTurn({required bool shouldUnmute}) async {
    if (_turnFinalizing) {
      return;
    }
    _turnFinalizing = true;
    try {
      await _flushPcmBuffer();
      await _audioQueue;
      if (!mounted) return;
      final shouldSuppressQueuedCards = _shouldSuppressQueuedTemplateCards(
        _currentModelTranscript,
      );
      _safeSetState(() {
        _appendTranscriptMessage(
          _TranscriptSpeaker.user,
          _currentUserTranscript,
        );
        _appendTranscriptMessage(
          _TranscriptSpeaker.assistant,
          _currentModelTranscript,
        );
        if (!shouldSuppressQueuedCards) {
          for (final card in _pendingTemplateCards) {
            _appendTemplateCard(card);
          }
        }
        _currentUserTranscript = null;
        _currentModelTranscript = null;
        _openingGreetingPendingUnmute = false;
        _modelResponding = false;
        _status = _currentStatus();
      });
      _clearPendingTurnState();
      if (shouldUnmute) {
        await _ensureLiveMicReady();
      }
    } finally {
      _turnFinalizing = false;
    }
  }

  bool _shouldSuppressQueuedTemplateCards(String? transcript) {
    final normalized = (transcript ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    const suppressionPhrases = <String>[
      "i didn't understand",
      "i did not understand",
      "i couldn't understand",
      "i could not understand",
      "i didn't catch",
      "i did not catch",
      "can you repeat",
      "could you repeat",
      "please repeat",
      "say that again",
      "come again",
      "not sure i understood",
      "i'm not sure i understood",
      "i am not sure i understood",
      "unclear",
      "didn't hear you",
      "did not hear you",
      "couldn't hear you",
      "could not hear you",
    ];
    return suppressionPhrases.any(normalized.contains);
  }
}
