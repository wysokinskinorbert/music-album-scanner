import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity state changes.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  late final StreamController<bool> _connectionController;
  bool _isOnline = true;

  ConnectivityService() {
    _connectionController = StreamController<bool>.broadcast();
    _connectivity.onConnectivityChanged.listen(_updateStatus);
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    if (wasOnline != _isOnline) {
      _connectionController.add(_isOnline);
    }
  }

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _connectionController.stream;

  void dispose() {
    _connectionController.close();
  }
}
