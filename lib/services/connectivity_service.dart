import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Detecta si el dispositivo tiene salida real a internet.
/// No basta con estar conectado a Wi-Fi: se valida resolucion DNS.
class ConnectivityService extends ChangeNotifier {
  bool _online = true;
  bool _checking = false;
  Timer? _timer;

  bool get online => _online;
  bool get offline => !_online;

  void start() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _check());
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    var ok = false;
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 4));
      ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
        ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        ok = false;
      }
    }
    if (ok != _online) {
      _online = ok;
      notifyListeners();
    }
    _checking = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
