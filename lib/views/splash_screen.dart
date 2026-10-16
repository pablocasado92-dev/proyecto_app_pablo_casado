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
    // 1. Inicializar el administrador de dispositivo
    DataHolder.instance.initDeviceAdmin(context);

    // 2. Tiempo de carga visual para apreciar la animación (2.5 segundos)
    await Future.delayed(const Duration(milliseconds: 2500));

    // 3. Consultar si hay una sesión de usuario activa en Firebase Auth
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    // 4. Lógica de navegación de sesión basada en el perfil del usuario:
    if (currentUser != null) {
      // Sesión iniciada activa -> Cargar perfil desde Firestore
      await DataHolder.instance.descargarPerfil();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Imagen animada (GIF) cargada desde una URL remota con control de estados
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                'https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExOW5qOXozaTR2dm91MjU4c2s0czFqNG9yNW16c2cxNnc3Ym85N21tdyZlcD12MV_pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/oVLqOvUWz2fUheuGNz/giphy.gif',
                height: 300,
                width: 300,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 220,
                    width: 220,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.movie_creation_outlined,
                    size: 100,
                    color: Colors.white,
                  );
                },
              ),
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
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
