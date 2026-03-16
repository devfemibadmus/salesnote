part of '../core.dart';

extension _LiveCashierOverlaySocketCapture on _LiveCashierOverlayState {
  String _openingGreetingPrompt() {
    const defaultGreeting =
        'Reply with exactly this and nothing else: Hello from SalesNote Live Cashier. How can I help with receipts, invoices, items, or reports?';

    final history = LocalCache.getLiveCashierActionHistory();
    if (history.isEmpty) {
      return defaultGreeting;
    }

    final recentActions = <String>[];
    for (final action in history.reversed) {
      final normalized = action.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (recentActions.contains(normalized)) {
        continue;
      }
      recentActions.add(normalized);
      if (recentActions.length == 3) {
        break;
      }
    }

    if (recentActions.isEmpty) {
      return defaultGreeting;
    }

    final actionText = recentActions.join(', ');
    final prompts = <String>[
      'Reply with one short natural greeting and ask what the user wants next. You may naturally reference one or two recent actions if helpful: $actionText. Do not list everything.',
      'Reply with a brief friendly welcome back and ask what they want to do now. If it sounds natural, mention a recent action such as: $actionText.',
      'Reply with one short conversational sentence asking how you can help next. You may lightly reference recent tasks like: $actionText.',
    ];
    return prompts[math.Random().nextInt(prompts.length)];
  }

  void _enqueuePcmChunk(String base64Data, String mimeType) {
    try {
      final pcmBytes = base64Decode(base64Data);
      if (pcmBytes.isEmpty) return;
      final rateMatch = RegExp(r'rate=(\d+)').firstMatch(mimeType);
      final sampleRate = int.tryParse(rateMatch?.group(1) ?? '') ?? 24000;
      _pcmBuffer.add(pcmBytes);
      if (_pcmBuffer.length < 2400) {
        return;
      }
      final bufferedBytes = _pcmBuffer.takeBytes();
      final epoch = _audioEpoch;
      _audioQueue = _audioQueue.then((_) async {
        if (epoch != _audioEpoch || _playerDisposed) return;
        await _ensurePlayerStarted(sampleRate);
        if (epoch != _audioEpoch || _playerDisposed || !_playerStarted) return;
        try {
          await _player.feedUint8FromStream(bufferedBytes);
        } catch (e) {
          _log('audio:feed:error $e');
        }
      });
    } catch (e) {
      _log('audio:enqueue:error $e');
    }
  }

  Future<void> _flushPcmBuffer() async {
    if (_pcmBuffer.isEmpty) {
      return;
    }
    final bufferedBytes = _pcmBuffer.takeBytes();
    final epoch = _audioEpoch;
    _audioQueue = _audioQueue.then((_) async {
      if (epoch != _audioEpoch || _playerDisposed || !_playerStarted) return;
      try {
        await _player.feedUint8FromStream(bufferedBytes);
      } catch (e) {
        _log('audio:flush:error $e');
      }
    });
  }

  Future<void> _startVoiceCapture() async {
    if (_loading || _error != null || !_connected || _isRecording) return;

    try {
      await _configureLiveAudioSession();
      final granted = await _recorder.hasPermission();
      if (!granted) {
        if (!mounted) return;
        _safeSetState(() {
          _status = 'Microphone permission is required for live cashier.';
        });
        return;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication,
            audioManagerMode: AudioManagerMode.modeInCommunication,
            service: AndroidService(
              title: 'Sales Note Live Cashier',
              content: 'Live cashier microphone is active',
            ),
          ),
          streamBufferSize: 4096,
        ),
      );

      await _recordingSub?.cancel();
      _recordingSub = stream.listen(
        _sendAudioChunk,
        onError: (error) {
          if (!mounted) return;
          _safeSetState(() {
            _status = 'Microphone stream error: $error';
            _isRecording = false;
          });
        },
      );

      if (!mounted) return;
      _safeSetState(() {
        _isRecording = true;
        _status = _currentStatus();
      });
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() {
        _isRecording = false;
        _status = 'Unable to start microphone capture.';
        _error = null;
      });
    }
  }

  void _sendAudioChunk(Uint8List chunk) {
    final socket = _socket;
    if (socket == null ||
        socket.readyState != WebSocket.open ||
        chunk.isEmpty) {
      return;
    }
    _markTurnPending();

    if (_audioChunkLogCount < 5) {
      _audioChunkLogCount += 1;
      _log('audio:chunk bytes=${chunk.length}');
    }

    socket.add(
      jsonEncode({
        'realtimeInput': {
          'audio': {
            'mimeType': 'audio/pcm;rate=16000',
            'data': base64Encode(chunk),
          },
        },
      }),
    );
  }

  Future<void> _stopVoiceCapture() async {
    if (!_isRecording) return;

    _safeSetState(() {
      _isRecording = false;
      _status = _currentStatus();
    });

    await _recordingSub?.cancel();
    _recordingSub = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    final socket = _socket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(
        jsonEncode({
          'realtimeInput': {'audioStreamEnd': true},
        }),
      );
    }
  }

  Future<void> _ensureLiveMicReady() async {
    if (!_isRecording) {
      await _startVoiceCapture();
    }
  }

  Future<void> _syncVoiceCaptureWithSessionState() async {
    if (_setupReady && _connected) {
      await _ensureLiveMicReady();
      return;
    }
    if (_isRecording) {
      await _stopVoiceCapture();
    }
  }

  void _sendOpeningGreeting() {
    if (_openingGreetingSent) return;
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    _openingGreetingSent = true;
    _log('greeting:send');
    if (mounted) {
      _safeSetState(() {
        _currentModelTranscript = null;
        _modelResponding = true;
        _status = _currentStatus();
      });
    }
    unawaited(_sendClientContentTurn(_openingGreetingPrompt()));
  }
}
