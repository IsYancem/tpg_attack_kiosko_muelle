import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

typedef StatusCallback = void Function(bool connected);

abstract class BaseService {
  final StatusCallback onStatus;

  final BehaviorSubject<bool> _isConnected$ = BehaviorSubject.seeded(false);
  Stream<bool> get isConnected$ => _isConnected$.stream;

  Timer? _probeTimer;
  bool _disposed = false;

  BaseService({required this.onStatus});

  void setConnected(bool value) {
    if (_disposed) return;

    try {
      _isConnected$.add(value);
      onStatus(value);
    } catch (_) {}
  }

  void startProbeLoop(Future<bool> Function() checkAlive) {
    _probeTimer?.cancel();

    _probeTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_disposed) {
        _probeTimer?.cancel();
        return;
      }

      try {
        final alive = await checkAlive();
        if (!_disposed) setConnected(alive);
      } catch (_) {
        if (!_disposed) setConnected(false);
      }
    });
  }

  void stopProbeLoop() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  @mustCallSuper
  void dispose() {
    _disposed = true;
    stopProbeLoop();
    _isConnected$.close();
  }
}