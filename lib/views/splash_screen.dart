import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';

/// PANTALLA DE CARGA INICIAL (SplashScreen)
/// Primera vista mostrada siempre al abrir o reiniciar la aplicación.
/// Muestra un GIF animado de Giphy y evalúa la sesión del usuario.
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

  /// Evalúa el estado de sesión y primerLogin para decidir el destino de navegación
  Future<void> _checkInitialRoute() async {
    try {
      // 1. Inicializar el administrador de dispositivo
      DataHolder.instance.initDeviceAdmin(context);

      // 2. Tiempo de carga visual para apreciar la animación (2.5 segundos)
      await Future.delayed(const Duration(milliseconds: 2500));

      if (!mounted) return;

      // 3. Consultar si hay una sesión de usuario activa en Firebase Auth
      final User? currentUser = FirebaseAuth.instance.currentUser;

      // 4. Lógica de navegación de sesión basada en el perfil del usuario:
      if (currentUser != null) {
        // Sesión iniciada activa -> Cargar perfil desde Firestore con timeout de seguridad
        try {
          await DataHolder.instance.descargarPerfil().timeout(
            const Duration(seconds: 4),
          );
        } catch (e) {
          debugPrint("Error descargando perfil en splash: $e");
        }

        DataHolder.instance.iniciarPresencia();

        if (!mounted) return;

        // Si es el primer login del usuario en su perfil, mostrar Onboarding justo antes de ir a Home
        if (DataHolder.instance.perfilUsuario.primerLogin) {
          Navigator.pushReplacementNamed(context, '/onboarding');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // Sesión no iniciada -> Ir directamente a la pantalla de Login
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint("Error en _checkInitialRoute: $e");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
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
            // Imagen representativa MTG cargada desde assets (formato optimizado WebP)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/splash_mtg.webp',
                height: 300,
                width: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.style_outlined,
                    size: 100,
                    color: Colors.white,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Planeswalker Hub',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Comunidad & Encuentros de Magic: The Gathering',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
