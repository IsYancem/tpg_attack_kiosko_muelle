import 'package:flutter/material.dart';

class AccessDeniedScreen extends StatelessWidget {
  final String username; // ← Nuevo campo

  const AccessDeniedScreen({
    super.key,
    required this.username, // ← Parámetro requerido
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Acceso denegado',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Aquí incluimos el username
            Text(
              'El usuario “$username” no tiene permisos para usar esta aplicación.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
