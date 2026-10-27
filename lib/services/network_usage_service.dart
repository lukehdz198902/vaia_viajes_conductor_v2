import 'package:shared_preferences/shared_preferences.dart';

/// Consumo HTTP aproximado de la app (peticiones y respuestas de la API).
/// No incluye WebSocket, trafico del sistema ni consumo de otras apps.
class NetworkUsageService {
  static const _kTotal = 'vaia_net_bytes_total';
  static const _kToday = 'vaia_net_bytes_today';
  static const _kDay = 'vaia_net_day';

  static int _totalBytes = 0;
  static int _todayBytes = 0;
  static String _day = '';

  static double get totalMB => _totalBytes / 1048576.0;
  static double get todayMB => _todayBytes / 1048576.0;

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _totalBytes = p.getInt(_kTotal) ?? 0;
    _day = _dateKey(DateTime.now());
    final savedDay = p.getString(_kDay) ?? '';
    _todayBytes = savedDay == _day ? (p.getInt(_kToday) ?? 0) : 0;
    await _save();
  }

  static Future<void> addSent(int bytes) => _add(bytes);
  static Future<void> addReceived(int bytes) => _add(bytes);

  static Future<void> _add(int bytes) async {
    if (bytes <= 0) return;
    final today = _dateKey(DateTime.now());
    if (today != _day) {
      _day = today;
      _todayBytes = 0;
    }
    _totalBytes += bytes;
    _todayBytes += bytes;
    await _save();
  }

  static Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kTotal, _totalBytes);
    await p.setInt(_kToday, _todayBytes);
    await p.setString(_kDay, _day);
  }
}
