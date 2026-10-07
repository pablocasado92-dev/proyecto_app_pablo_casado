import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================================
/// BLOQUE 1: PANTALLA DE CARGA INICIAL (SplashScreen)
/// ============================================================================
/// Esta es la primera pantalla que se muestra al abrir la aplicación.
/// Muestra un indicador de carga y evalúa asíncronamente a qué vista redirigir:
///  1. Si NO ha visto el onboarding -> Redirige a '/onboarding'.
///  2. Si YA lo vio y hay sesión activa en Firebase -> Redirige a '/home'.
///  3. Si YA lo vio pero NO hay sesión activa -> Redirige a '/login'.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Ejecuta la evaluación de ruta al iniciar el widget
    _checkInitialRoute();
  }

  /// Evalúa las condiciones asíncronas para decidir la pantalla inicial
  Future<void> _checkInitialRoute() async {
    // 1. Simulación visual de tiempo de carga (1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    // 2. Consulta en SharedPreferences si ya se completó el onboarding
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    // 3. Consulta si hay un usuario autenticado en Firebase Auth
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    // 4. Decisión de navegación mediante rutas nombradas
    if (!seenOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else if (currentUser != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono animado/representativo de la app
            const Icon(
              Icons.flutter_dash,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            const Text(
              'Proyecto App',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            // Indicador de progreso circular
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
