part of '../live_cashier.dart';

extension _LiveCashierOverlaySocket on _LiveCashierOverlayState {
  Uri _backendLiveSocketUri() {
    final apiUri = Uri.parse(AppConfig.apiBaseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return apiUri.replace(
      scheme: scheme,
      path: '/live-agent/socket',
      queryParameters: null,
      fragment: null,
    );
  }

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

  Future<void> _finalizeTurn({required bool shouldUnmute}) async {
    if (_turnFinalizing) {
      return;
    }
    _turnFinalizing = true;
    try {
      final shouldRestoreMic = _autoMutedForPlayback;
      await _flushPcmBuffer();
      await _audioQueue;
      if (!mounted) return;
      _safeSetState(() {
        _appendTranscriptMessage(_TranscriptSpeaker.user, _currentUserTranscript);
        _appendTranscriptMessage(
          _TranscriptSpeaker.assistant,
          _currentModelTranscript,
        );
        _currentUserTranscript = null;
        _currentModelTranscript = null;
        _openingGreetingPendingUnmute = false;
        _modelResponding = false;
        _autoMutedForPlayback = false;
        _status = _currentStatus();
      });
      if (shouldUnmute || shouldRestoreMic) {
        await _ensureLiveMicReady();
      }
    } finally {
      _turnFinalizing = false;
    }
  }

  Future<void> _bootstrap() async {
    _log('bootstrap:start');
    try {
      final token = await TokenStore().getToken();
      
      await Future.wait([
        _connectLive(token),
        _configurePlayer(),
      ]);

      if (!mounted) return;
      _safeSetState(() {
        _loading = false;
        _status = 'Starting live cashier...';
      });
    } catch (e) {
      _log('bootstrap:error $e');
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Unable to start live cashier right now.';
      _safeSetState(() {
        _error = message;
        _loading = false;
        _status = message;
      });
    }
  }

  Future<void> _connectLive(String? token) async {
    final uri = _backendLiveSocketUri();
    final headers = <String, dynamic>{
      ...AppConfig.defaultRequestHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      _log('socket:connect $uri');
      final socket = await WebSocket.connect(uri.toString(), headers: headers);
      socket.pingInterval = const Duration(seconds: 20);
      _socket = socket;
      socket.listen(
        _handleSocketMessage,
        onDone: _handleSocketDone,
        onError: _handleSocketError,
        cancelOnError: false,
      );

      if (!mounted) return;
      _safeSetState(() {
        _connected = true;
        _status = 'Starting live cashier...';
      });
    } catch (e) {
      _log('socket:connect:error $e');
      if (!mounted) return;
      _safeSetState(() {
        _error = 'Unable to connect live session.';
        _status = '$e';
      });
    }
  }


  void _handleSocketMessage(dynamic raw) {
    try {
      final rawText = _socketMessageText(raw);
      if (rawText == null || rawText.trim().isEmpty) {
        _log('socket:message:unsupported ${raw.runtimeType}');
        return;
      }
      final decoded = jsonDecode(rawText);
      if (decoded is! Map<String, dynamic>) return;
      _log('socket:message ${_socketMessageSummary(decoded)}');

      if (decoded.containsKey('setupComplete') && mounted) {
        _log('socket:setupComplete');
        unawaited(_handleSetupComplete());
      }

      final usageMetadata = decoded['usageMetadata'];
      if (usageMetadata != null) {
        _log('socket:usage $usageMetadata');
      }

      final serverContent = decoded['serverContent'];
      if (serverContent is Map<String, dynamic>) {
        if (serverContent['interrupted'] == true) {
          unawaited(_stopPlayerStream(forceStop: true));
          if (mounted) {
            _safeSetState(() {
              _modelResponding = false;
              _status = _currentStatus();
            });
          }
        }

        final inputTranscription = serverContent['inputTranscription'];
        if (inputTranscription is Map<String, dynamic>) {
          final text = (inputTranscription['text'] ??
                  inputTranscription['transcript'])
              ?.toString();
          if (text != null && text.trim().isNotEmpty && mounted) {
            _safeSetState(() {
              _currentUserTranscript =
                  _mergeTranscript(_currentUserTranscript, text);
            });
          }
        }

        final outputTranscription = serverContent['outputTranscription'];
        if (outputTranscription is Map<String, dynamic>) {
          final text = (outputTranscription['text'] ??
                  outputTranscription['transcript'])
              ?.toString();
          final spoken = text?.trim();
          if (spoken != null && spoken.isNotEmpty && mounted) {
            unawaited(_muteMicForPlayback());
            _safeSetState(() {
              _currentModelTranscript =
                  _mergeTranscript(_currentModelTranscript, spoken);
              _modelResponding = true;
              _status = _currentStatus();
            });
          }
        }

        final modelTurn = serverContent['modelTurn'];
        if (modelTurn is Map<String, dynamic>) {
          final parts = modelTurn['parts'];
          if (parts is List) {
            for (final part in parts) {
              if (part is Map<String, dynamic>) {
                final inlineData = part['inlineData'];
                if (inlineData is Map<String, dynamic>) {
                  final mimeType = inlineData['mimeType']?.toString() ?? '';
                  final base64Data = inlineData['data']?.toString();
                  if (mimeType.startsWith('audio/pcm') &&
                      base64Data != null &&
                      base64Data.isNotEmpty) {
                    unawaited(_muteMicForPlayback());
                    _enqueuePcmChunk(base64Data, mimeType);
                    if (mounted) {
                      _safeSetState(() {
                        _modelResponding = true;
                        _status = _currentStatus();
                      });
                    }
                    continue;
                  }
                }
              }
            }
          }
        }

        final generationComplete = serverContent['generationComplete'] == true;
        if (generationComplete) {
          _log('socket:generationComplete');
        }

        final turnComplete = serverContent['turnComplete'] == true;
        if (turnComplete && mounted) {
          final shouldUnmute = _openingGreetingPendingUnmute;
          unawaited(_finalizeTurn(shouldUnmute: shouldUnmute));
        }
      }

      final toolCall = decoded['toolCall'];
      if (toolCall is Map<String, dynamic>) {
        final functionCalls = toolCall['functionCalls'];
        if (functionCalls is List) {
          unawaited(_handleToolCalls(functionCalls));
        }
      }
    } catch (e) {
      _log('socket:parse:error $e');
      if (mounted) {
        _safeSetState(() => _status = 'Live session error.');
      }
    }
  }

  String? _socketMessageText(dynamic raw) {
    if (raw is String) {
      return raw;
    }
    if (raw is Uint8List) {
      return utf8.decode(raw, allowMalformed: true);
    }
    if (raw is List<int>) {
      return utf8.decode(raw, allowMalformed: true);
    }
    if (raw is ByteBuffer) {
      return utf8.decode(raw.asUint8List(), allowMalformed: true);
    }
    return null;
  }

  String _truncateLog(String value, {int max = 1200}) {
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max)}...';
  }

  String _socketMessageSummary(Map<String, dynamic> decoded) {
    final parts = <String>[];
    if (decoded.containsKey('setupComplete')) {
      parts.add('setupComplete');
    }
    final usageMetadata = decoded['usageMetadata'];
    if (usageMetadata is Map<String, dynamic>) {
      final totalTokens = usageMetadata['totalTokenCount'];
      if (totalTokens != null) {
        parts.add('usage.total=$totalTokens');
      }
    }
    final serverContent = decoded['serverContent'];
    if (serverContent is Map<String, dynamic>) {
      if (serverContent['interrupted'] == true) {
        parts.add('interrupted');
      }
      if (serverContent['generationComplete'] == true) {
        parts.add('generationComplete');
      }
      if (serverContent['turnComplete'] == true) {
        parts.add('turnComplete');
      }
      final inputTranscription = serverContent['inputTranscription'];
      if (inputTranscription is Map<String, dynamic>) {
        final text = (inputTranscription['text'] ??
                inputTranscription['transcript'])
            ?.toString()
            .trim();
        if (text != null && text.isNotEmpty) {
          parts.add('input="${_truncateLog(text, max: 80)}"');
        }
      }
      final outputTranscription = serverContent['outputTranscription'];
      if (outputTranscription is Map<String, dynamic>) {
        final text = (outputTranscription['text'] ??
                outputTranscription['transcript'])
            ?.toString()
            .trim();
        if (text != null && text.isNotEmpty) {
          parts.add('output="${_truncateLog(text, max: 80)}"');
        }
      }
      final modelTurn = serverContent['modelTurn'];
      if (modelTurn is Map<String, dynamic>) {
        final modelParts = modelTurn['parts'];
        if (modelParts is List) {
          var audioChunkCount = 0;
          for (final part in modelParts) {
            if (part is! Map<String, dynamic>) {
              continue;
            }
            final inlineData = part['inlineData'];
            if (inlineData is Map<String, dynamic>) {
              final mimeType = inlineData['mimeType']?.toString() ?? '';
              if (mimeType.startsWith('audio/pcm')) {
                audioChunkCount += 1;
              }
            }
          }
          if (audioChunkCount > 0) {
            parts.add('audioChunks=$audioChunkCount');
          }
        }
      }
    }
    final toolCall = decoded['toolCall'];
    if (toolCall is Map<String, dynamic>) {
      final functionCalls = toolCall['functionCalls'];
      if (functionCalls is List && functionCalls.isNotEmpty) {
        final names = functionCalls
            .whereType<Map<String, dynamic>>()
            .map((call) => call['name']?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList(growable: false);
        if (names.isNotEmpty) {
          parts.add('toolCall=${names.join(',')}');
        }
      }
    }
    if (parts.isEmpty) {
      return 'payload';
    }
    return parts.join(' ');
  }

  String _mergeTranscript(String? current, String incoming) {
    var next = incoming.trim();
    if (next.isEmpty) return current ?? '';
    var existing = (current ?? '').trim();
    if (existing.isEmpty) return next;
    
    if (next.contains(existing)) return next;
    
    return '$existing $next';
  }


  Future<void> _captureAndSendPhoto() async {
    final socket = _socket;
    if (!_connected ||
        socket == null ||
        socket.readyState != WebSocket.open ||
        _capturingPhoto) {
      return;
    }

    _safeSetState(() {
      _capturingPhoto = true;
      _status = 'Opening camera...';
    });
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 65,
        maxWidth: 1024,
      );
      if (file == null) {
        if (!mounted) return;
        _safeSetState(() {
          _capturingPhoto = false;
          _status = _currentStatus();
        });
        return;
      }
      final bytes = await file.readAsBytes();
      _log('photo:send bytes=${bytes.length}');
      socket.add(jsonEncode({
        'realtimeInput': {
          'mediaChunks': [
            {
              'mimeType': 'image/jpeg',
              'data': base64Encode(bytes),
            }
          ],
        }
      }));
      if (!mounted) return;
      _safeSetState(() {
        _capturingPhoto = false;
        _status = 'Photo sent. Ask about what Gemini sees.';
      });
    } catch (e) {
      _log('photo:error $e');
      if (!mounted) return;
      _safeSetState(() {
        _capturingPhoto = false;
        _status = 'Unable to take photo right now.';
      });
    } finally {
      if (mounted) {
        _safeSetState(() {
          _capturingPhoto = false;
        });
      }
    }
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
        chunk.isEmpty ||
        _micMuted) {
      return;
    }

    if (_audioChunkLogCount < 5) {
      _audioChunkLogCount += 1;
      _log('audio:chunk bytes=${chunk.length}');
    }

    socket.add(jsonEncode({
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=16000',
          'data': base64Encode(chunk),
        },
      }
    }));
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
      socket.add(jsonEncode({
        'realtimeInput': {'audioStreamEnd': true}
      }));
    }
  }

  Future<void> _handleSetupComplete() async {
    if (_setupReady) return;
    _setupReady = true;
    if (mounted) {
      _safeSetState(() {
        _status = 'Starting live cashier...';
      });
    }
    _sendOpeningGreeting();
  }

  Future<void> _setMicMuted(bool value, {bool sendAudioEnd = true}) async {
    if (_micMuted == value && _isRecording) {
      if (mounted) {
        _safeSetState(() => _status = _currentStatus());
      }
      return;
    }
    final wasMuted = _micMuted;
    _micMuted = value;
    if (mounted) {
      _safeSetState(() => _status = _currentStatus());
    }
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      return;
    }
    if (wasMuted && !value) {
      _log('mic:unmuted');
      return;
    }
    if (!wasMuted && value && sendAudioEnd) {
      socket.add(jsonEncode({
        'realtimeInput': {'audioStreamEnd': true}
      }));
    }
  }

  Future<void> _muteMicForPlayback() async {
    if (_micMuted || _playerDisposed) {
      return;
    }
    _autoMutedForPlayback = true;
    await _setMicMuted(true);
    _log('mic:auto-muted for playback');
  }

  Future<void> _toggleMute() async {
    if (_modelResponding) {
      _log('mic:toggle:ignored while model speaking');
      return;
    }
    if (!_isRecording) {
      await _startVoiceCapture();
      await _setMicMuted(false);
      return;
    }
    await _setMicMuted(!_micMuted);
  }

  Future<void> _ensureLiveMicReady() async {
    if (!_isRecording) {
      await _startVoiceCapture();
    }
    // Only auto-unmute if we are currently muted
    if (_micMuted) {
      await _setMicMuted(false, sendAudioEnd: false);
      _log('mic:auto-unmute');
    }
  }

  void _sendOpeningGreeting() {
    if (_openingGreetingSent) return;
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    _openingGreetingSent = true;
    _openingGreetingPendingUnmute = true;
    _log('greeting:send');
    if (mounted) {
      _safeSetState(() {
        _currentModelTranscript = null;
        _modelResponding = true;
        _status = _currentStatus();
      });
    }
    socket.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'Reply with exactly this and nothing else: Hello from SalesNote Live Cashier. How can I help with receipts, invoices, items, or reports?'
              }
            ],
          }
        ],
        'turnComplete': true,
      }
    }));
  }

  String _currentStatus() {
    if (_modelResponding) {
      return '';
    }
    if (_micMuted) {
      return 'Muted';
    }
    if (_isRecording) {
      return '';
    }
    return 'Connecting...';
  }


  void _handleSocketDone() {
    _log(
      'socket:done code=${_socket?.closeCode} reason=${_socket?.closeReason}',
    );
    _recordingSub?.cancel();
    _recordingSub = null;
    unawaited(_stopPlayerStream());
    if (!mounted) return;
    _safeSetState(() {
      _connected = false;
      _isRecording = false;
      _status = 'Connection ended.';
    });
  }

  void _handleSocketError(dynamic error) {
    _log('socket:error $error');
    _recordingSub?.cancel();
    _recordingSub = null;
    unawaited(_stopPlayerStream());
    if (!mounted) return;
    _safeSetState(() {
      _connected = false;
      _isRecording = false;
      _status = 'Live cashier unavailable.';
    });
  }

  Future<void> _closeOverlay() async {
    await _stopVoiceCapture();
    await _stopPlayerStream(forceStop: true);
    await _socket?.close();
    _socket = null;
    if (!mounted) return;
    Navigator.of(context).pop();
    if (_pendingRoute != null) {
      AppNavigator.key.currentState?.pushNamed(_pendingRoute!, arguments: _pendingArgs);
    }
  }
}
