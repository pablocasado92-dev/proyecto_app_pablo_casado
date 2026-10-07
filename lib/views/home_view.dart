import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/data_holder.dart';

/// ============================================================================
/// BLOQUE 5: PANTALLA PRINCIPAL (HomeView)
/// ============================================================================
/// Esta vista actúa como el panel de control del usuario autenticado.
/// Muestra la información del perfil obtenida de Firebase Auth o DataHolder,
/// y ofrece la opción de cerrar sesión de forma segura.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  /// Realiza el cierre de sesión del usuario
  Future<void> _signOut(BuildContext context) async {
    // 1. Cerrar la sesión activa en Firebase Authentication
    await FirebaseAuth.instance.signOut();
    
    // 2. Limpiar los datos almacenados en el DataHolder global
    DataHolder().clearData();

    if (!context.mounted) return;

    // 3. Redirigir al Login eliminando todo el historial de navegación previa
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Obtener la sesión activa de Firebase Auth si existe
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    
    // 2. Recuperar email y nombre (priorizando Firebase y fallback al DataHolder)
    final String userEmail = firebaseUser?.email ?? 
        (DataHolder().userEmail.isNotEmpty ? DataHolder().userEmail : 'Invitado');
    final String userName = firebaseUser?.displayName ?? 
        (DataHolder().userName.isNotEmpty ? DataHolder().userName : 'Usuario');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal (Home View)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Botón de cerrar sesión en la barra superior
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Tarjeta visual con los datos del usuario logueado
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.deepPurple,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                '¡Bienvenido a tu HomeView!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Has iniciado sesión correctamente. Aquí se muestran los datos del usuario introducidos al registrarte o iniciar sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              
              // Botón inferor para cerrar sesión
              ElevatedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
