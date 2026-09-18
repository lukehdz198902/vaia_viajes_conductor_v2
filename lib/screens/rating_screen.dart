import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class RatingScreen extends StatefulWidget {
  final int? idServicio;
  const RatingScreen({super.key, this.idServicio});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar Viaje'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, size: 80, color: AppTheme.secondary),
              const SizedBox(height: 24),
              const Text('Viaje Completado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text('Califica al pasajero', style: TextStyle(color: AppTheme.textMedium)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    iconSize: 48,
                    icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: AppTheme.secondary),
                    onPressed: () => setState(() => _rating = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando
                      ? null
                      : () async {
                          final ride = context.read<RideProvider>();
                          final auth = context.read<AuthProvider>();
                          final navigator = Navigator.of(context);
                          if (_rating > 0 && widget.idServicio != null) {
                            setState(() => _enviando = true);
                            await ride.calificarPasajero(widget.idServicio!, auth.userId, _rating);
                            if (!mounted) return;
                            setState(() => _enviando = false);
                          }
                          navigator.pushReplacementNamed('/home');
                        },
                  child: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Finalizar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
