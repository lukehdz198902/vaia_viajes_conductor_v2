import 'package:flutter/foundation.dart';
import '../models/unidad_model.dart';
import '../models/corte_model.dart';
import '../services/api_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _loading = false;
  String? _error;
  List<Unidad> _unidades = [];
  Unidad? _selectedUnidad;
  CorteSemanal? _currentCorte;

  bool get loading => _loading;
  String? get error => _error;
  List<Unidad> get unidades => _unidades;
  Unidad? get selectedUnidad => _selectedUnidad;
  CorteSemanal? get currentCorte => _currentCorte;

  Future<void> loadUnidades(int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.listarUnidades(conductorId);
    if (resp.ok && resp.list != null) {
      _unidades = resp.list!.map((e) => Unidad.fromJson(e)).toList();
      _selectedUnidad = _unidades.cast<Unidad?>().firstWhere((u) => u?.enUso == true, orElse: () => null);
    }
    _loading = false; notifyListeners();
  }

  Future<bool> selectUnidad(int conductorId, int unidadId) async {
    _loading = true; notifyListeners();
    final resp = await _api.seleccionarUnidad(conductorId, unidadId);
    _loading = false;
    if (resp.ok) {
      await loadUnidades(conductorId);
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }

  Future<void> loadCorte(int conductorId) async {
    _loading = true; notifyListeners();
    final resp = await _api.obtenerSemanaCorte(conductorId);
    if (resp.ok && resp.list != null && resp.list!.isNotEmpty) {
      _currentCorte = CorteSemanal.fromJson(resp.list!.first as Map<String, dynamic>);
    }
    _loading = false; notifyListeners();
  }

  Future<bool> transferirCorte(int conductorId, int corteId) async {
    _loading = true; notifyListeners();
    final resp = await _api.transferirSemanaCorte(conductorId, corteId);
    _loading = false;
    if (resp.ok) {
      await loadCorte(conductorId);
      return true;
    }
    _error = resp.mensaje;
    notifyListeners();
    return false;
  }
}
