part of '../core.dart';

extension _LiveCashierOverlaySocketConnection on _LiveCashierOverlayState {
  Future<void> _retryBootstrap() async {
    if (_retryingBootstrap) {
      return;
    }
    if (mounted) {
      _safeSetState(() {
        _retryingBootstrap = true;
      });
    }
    try {
      await _bootstrap();
    } finally {
      if (mounted) {
        _safeSetState(() {
          _retryingBootstrap = false;
        });
      }
    }
  }

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

  Future<void> _bootstrap() async {
    _log('bootstrap:start');
    _closingOverlay = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _reconnectSecondsRemaining = 0;
    _reconnecting = false;
    try {
      final token = await TokenStore().getToken();

      await Future.wait([_connectLive(token), _configurePlayer()]);

      if (!mounted) return;
      _safeSetState(() {
        _error = null;
        _loading = false;
        _status = _currentStatus();
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

  Future<void> _connectLive(
    String? token, {
    bool backgroundReconnect = false,
  }) async {
    final uri = _backendLiveSocketUri();
    final headers = <String, dynamic>{
      ...AppConfig.defaultRequestHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      _log('socket:connect $uri');
      _socket = null;
      _setupReady = false;
      final socket = await WebSocket.connect(uri.toString(), headers: headers);
      socket.pingInterval = TimingConstants.liveCashierSocketPingInterval;
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
        _error = null;
        _reconnecting = false;
        _reconnectAttempt = 0;
        _reconnectSecondsRemaining = 0;
        _status = backgroundReconnect
            ? 'Reconnected. Restoring session...'
            : 'Starting live cashier...';
      });
      if (backgroundReconnect) {
        unawaited(LiveCashierCueService.playReconnected());
      }
    } catch (e) {
      _log('socket:connect:error $e');
      if (!mounted) return;
      _safeSetState(() {
        _connected = false;
        _status = backgroundReconnect ? _currentStatus() : '$e';
        if (!backgroundReconnect) {
          _error = 'Unable to connect live session.';
        }
      });
      rethrow;
    }
  }

  void _scheduleReconnect({String? reason}) {
    if (_closingOverlay || !mounted) {
      return;
    }
    if (_reconnectTimer != null) {
      return;
    }
    final shouldPlayCue = _reconnectAttempt == 0;
    _reconnecting = true;
    _reconnectAttempt += 1;
    final delaySeconds = _reconnectAttempt <= 1
        ? 1
        : _reconnectAttempt == 2
        ? 2
        : _reconnectAttempt == 3
        ? 4
        : _reconnectAttempt == 4
        ? 8
        : 12;
    _log(
      'socket:reconnect:scheduled attempt=$_reconnectAttempt '
      'delay=${delaySeconds}s reason=${reason ?? "-"}',
    );
    _safeSetState(() {
      _reconnectSecondsRemaining = delaySeconds;
      _toolBusy = false;
      _toolStatus = _reconnectCountdownLabel();
      _status = _currentStatus();
    });
    if (shouldPlayCue) {
      unawaited(LiveCashierCueService.playReconnecting());
    }
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_closingOverlay || !mounted) {
        timer.cancel();
        _reconnectTimer = null;
        return;
      }
      if (_reconnectSecondsRemaining <= 1) {
        timer.cancel();
        _reconnectTimer = null;
        _reconnectSecondsRemaining = 0;
        unawaited(_attemptReconnect());
        return;
      }
      _safeSetState(() {
        _reconnectSecondsRemaining -= 1;
        _toolStatus = _reconnectCountdownLabel();
        _status = _currentStatus();
      });
    });
  }

  String _reconnectCountdownLabel() {
    if (_reconnectSecondsRemaining > 0) {
      return 'Disconnected. Reconnecting in ${_reconnectSecondsRemaining}s.';
    }
    return 'Disconnected. Reconnecting...';
  }

  Future<void> _attemptReconnect() async {
    if (_closingOverlay || !mounted) {
      return;
    }
    try {
      final token = await TokenStore().getToken();
      await _connectLive(token, backgroundReconnect: true);
    } catch (e) {
      if (!mounted || _closingOverlay) {
        return;
      }
      _scheduleReconnect(reason: e.toString());
    }
  }

  Future<void> _handleSetupComplete() async {
    if (_setupReady) return;
    _setupReady = true;
    if (mounted) {
      _safeSetState(() {
        _toolStatus = null;
        _status = _currentStatus();
      });
    }
    if (_openingGreetingSent) {
      await _restorePendingTurnIfNeeded();
      if (!_micMuted) {
        await _ensureLiveMicReady();
      }
      return;
    }
    if (!_micMuted) {
      await _ensureLiveMicReady();
    }
    unawaited(LiveCashierCueService.playBootstrapReady());
    _sendOpeningGreeting();
  }

  String _currentStatus() {
    if (!_connected) {
      if (_reconnecting) {
        return _reconnectCountdownLabel();
      }
      return 'Disconnected';
    }
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

  void _handleSocketDisconnect({required String reason, dynamic error}) {
    _log(reason);
    _socket = null;
    _setupReady = false;
    _clearSalesWindowCache();
    _recordingSub?.cancel();
    _recordingSub = null;
    unawaited(_stopPlayerStream());
    if (!mounted) return;
    _safeSetState(() {
      _connected = false;
      _isRecording = false;
      _modelResponding = false;
      _status = _currentStatus();
    });
    if (_closingOverlay) {
      return;
    }
    _scheduleReconnect(reason: error?.toString() ?? reason);
  }

  void _handleSocketDone() {
    _handleSocketDisconnect(
      reason:
          'socket:done code=${_socket?.closeCode} reason=${_socket?.closeReason}',
    );
  }

  void _handleSocketError(dynamic error) {
    _handleSocketDisconnect(reason: 'socket:error $error', error: error);
  }

  Future<void> _closeOverlay() async {
    _closingOverlay = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectSecondsRemaining = 0;
    await _stopVoiceCapture();
    await _stopPlayerStream(forceStop: true);
    await _socket?.close();
    _socket = null;
    if (!mounted) return;
    final pendingRoute = _pendingRoute;
    final pendingArgs = _pendingArgs;
    final pendingPostCloseAction = _pendingPostCloseAction;
    _pendingRoute = null;
    _pendingArgs = null;
    _pendingPostCloseAction = null;
    Navigator.of(context).pop();
    if (pendingRoute != null) {
      AppNavigator.key.currentState?.pushNamed(
        pendingRoute,
        arguments: pendingArgs,
      );
    }
    if (pendingPostCloseAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(pendingPostCloseAction());
      });
    }
  }
}
