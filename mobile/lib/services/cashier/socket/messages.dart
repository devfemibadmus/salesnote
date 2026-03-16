part of '../core.dart';

extension _LiveCashierOverlaySocketMessages on _LiveCashierOverlayState {
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
          final text =
              (inputTranscription['text'] ?? inputTranscription['transcript'])
                  ?.toString();
          if (text != null && text.trim().isNotEmpty && mounted) {
            final replayText = _mergeTranscript(_pendingReplayUserText, text);
            _markTurnPending(replayText: replayText);
            final mergedTranscript = _mergeTranscript(
              _currentUserTranscript,
              text,
            );
            if (mergedTranscript != (_currentUserTranscript ?? '').trim()) {
              _safeSetState(() {
                _currentUserTranscript = mergedTranscript;
              });
            }
          }
        }

        final outputTranscription = serverContent['outputTranscription'];
        if (outputTranscription is Map<String, dynamic>) {
          final text =
              (outputTranscription['text'] ?? outputTranscription['transcript'])
                  ?.toString();
          final spoken = text?.trim();
          if (spoken != null && spoken.isNotEmpty && mounted) {
            final mergedTranscript = _mergeTranscript(
              _currentModelTranscript,
              spoken,
            );
            final transcriptChanged =
                mergedTranscript != (_currentModelTranscript ?? '').trim();
            if (transcriptChanged || !_modelResponding) {
              _safeSetState(() {
                _currentModelTranscript = mergedTranscript;
                _modelResponding = true;
                _status = _currentStatus();
              });
            }
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
                    _enqueuePcmChunk(base64Data, mimeType);
                    if (mounted && !_modelResponding) {
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
        final text =
            (inputTranscription['text'] ?? inputTranscription['transcript'])
                ?.toString()
                .trim();
        if (text != null && text.isNotEmpty) {
          parts.add('input="${_truncateLog(text, max: 80)}"');
        }
      }
      final outputTranscription = serverContent['outputTranscription'];
      if (outputTranscription is Map<String, dynamic>) {
        final text =
            (outputTranscription['text'] ?? outputTranscription['transcript'])
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
    final next = incoming.trim();
    if (next.isEmpty) {
      return (current ?? '').trim();
    }

    final existing = (current ?? '').trim();
    if (existing.isEmpty) {
      return next;
    }

    final existingLower = existing.toLowerCase();
    final nextLower = next.toLowerCase();
    if (existingLower == nextLower) {
      return existing;
    }
    if (nextLower.contains(existingLower)) {
      return next;
    }
    if (existingLower.contains(nextLower)) {
      return existing;
    }

    final maxOverlap = math.min(existing.length, next.length);
    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      if (existingLower.endsWith(nextLower.substring(0, overlap))) {
        return '$existing${next.substring(overlap)}'.trim();
      }
    }

    return '$existing $next';
  }
}
