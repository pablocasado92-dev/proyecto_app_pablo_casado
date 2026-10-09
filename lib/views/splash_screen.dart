import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/data_holder.dart';

/// ============================================================================
/// PANTALLA DE CARGA INICIAL (SplashScreen)
/// ============================================================================
/// Primera vista mostrada siempre al abrir la aplicación.
/// Muestra el logo y evalúa si es la primera vez que se entra en la app:
///  - Si NO ha entrado ninguna vez -> Redirige a '/onboarding'.
///  - Si YA ha entrado previamente -> Redirige a '/login'.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  /// Evalúa si el usuario ya vio el onboarding para decidir el destino
  Future<void> _checkInitialRoute() async {
    // 1. Inicializar el administrador de dispositivo
    DataHolder.instance.initDeviceAdmin(context);

    // 2. Tiempo de carga visual del Splash Screen (1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    // 3. Consultar en SharedPreferences si ya se vio el onboarding
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (!mounted) return;

    // 4. Lógica estricta de navegación solicitada:
    // Si no ha entrado ninguna vez -> Onboarding. Sino -> Login.
    if (!seenOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
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
            // Icono del Splash Screen
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
            // Indicador de carga animado
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
