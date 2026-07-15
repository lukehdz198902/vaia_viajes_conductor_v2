import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _appCtrl = TextEditingController();
  final _apmCtrl = TextEditingController();
  final _correoCtr = TextEditingController();
  final _telCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _appCtrl.dispose();
    _apmCtrl.dispose();
    _correoCtr.dispose();
    _telCtrl.dispose();
    _accountCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final data = {
      'idCompania': '1',
      'nombre': _nombreCtrl.text.trim(),
      'appaterno': _appCtrl.text.trim(),
      'apmaterno': _apmCtrl.text.trim(),
      'sexo': 'M',
      'correo': _correoCtr.text.trim(),
      'telefono': _telCtrl.text.trim(),
      'googlekey': '',
      'account': _accountCtrl.text.trim(),
      'pass': _passCtrl.text,
    };
    final ok = await auth.register(data);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso. Inicia sesión.'), backgroundColor: AppTheme.accent),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Error al registrar'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Registro Conductor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre*', prefixIcon: Icon(Icons.person)), validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _appCtrl, decoration: const InputDecoration(labelText: 'Apellido Paterno*', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _apmCtrl, decoration: const InputDecoration(labelText: 'Apellido Materno', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 12),
              TextFormField(controller: _correoCtr, decoration: const InputDecoration(labelText: 'Correo*', prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress, validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _telCtrl, decoration: const InputDecoration(labelText: 'Teléfono*', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone, validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _accountCtrl, decoration: const InputDecoration(labelText: 'Usuario*', prefixIcon: Icon(Icons.account_circle)), validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _passCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: 'Contraseña*', prefixIcon: const Icon(Icons.lock), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure))), validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar Contraseña*', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v != _passCtrl.text ? 'No coincide' : null),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _register,
                  child: auth.loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Registrarse'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
