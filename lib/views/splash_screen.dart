import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_holder.dart';

/// ============================================================================
/// PANTALLA DE CARGA INICIAL (SplashScreen)
/// ============================================================================
/// Primera vista mostrada siempre al abrir o reiniciar la aplicación.
/// Evalúa el estado de inicio de sesión de Firebase Auth y de onboarding:
///  - Si NO ha visto el onboarding -> Redirige a '/onboarding'.
///  - Si TIENE sesión activa -> Descarga perfil y va directamente a '/home'.
///  - Si NO tiene sesión activa -> Redirige a '/login'.
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

  /// Evalúa el estado de sesión y onboarding para decidir el destino de navegación
  Future<void> _checkInitialRoute() async {
    // 1. Inicializar el administrador de dispositivo
    DataHolder.instance.initDeviceAdmin(context);

    // 2. Tiempo de carga visual del Splash Screen (1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    // 3. Consultar en SharedPreferences si ya se vio el onboarding
    final prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    // 4. Consultar si hay una sesión de usuario activa en Firebase Auth
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    // 5. Lógica de navegación inteligente de sesión:
    if (!seenOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else if (currentUser != null) {
      // Sesión iniciada activa -> Cargar perfil e ir directo a la pantalla principal
      await DataHolder.instance.descargarPerfil();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Sesión no iniciada -> Ir al login
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
            const Icon(Icons.flutter_dash, size: 100, color: Colors.white),
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
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            // Indicador de carga animado
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
