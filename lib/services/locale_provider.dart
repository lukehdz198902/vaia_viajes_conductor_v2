import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idioma de la app (espanol / ingles), persistido entre sesiones.
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';
  String _lang = 'es';

  String get lang => _lang;
  bool get esIngles => _lang == 'en';
  Locale get locale => Locale(_lang);

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lang = prefs.getString(_key) ?? 'es';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLang(String lang) async {
    _lang = lang == 'en' ? 'en' : 'es';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _lang);
    } catch (_) {}
    notifyListeners();
  }
}

/// Traduce un texto en linea: `S.t(context, 'Espanol', 'English')`.
class S {
  static String t(BuildContext context, String es, String en) {
    final lang = context.watch<LocaleProvider>().lang;
    return lang == 'en' ? en : es;
  }
}
