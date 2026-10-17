import 'dart:convert';
import 'package:flutter/material.dart';

/// Devuelve un ImageProvider a partir de una foto que puede venir como base64
/// (almacenada en la base de datos) o como URL (por ejemplo de Google).
/// Retorna null si no hay foto o no se puede decodificar.
ImageProvider? providerFoto(String? foto) {
  if (foto == null) return null;
  var f = foto.trim();
  if (f.isEmpty) return null;
  final comma = f.indexOf(',');
  if (f.startsWith('data:') && comma >= 0) f = f.substring(comma + 1);
  if (f.startsWith('http://') || f.startsWith('https://')) {
    return NetworkImage(f);
  }
  try {
    return MemoryImage(base64Decode(f.replaceAll(RegExp(r'\s'), '')));
  } catch (_) {
    return null;
  }
}
