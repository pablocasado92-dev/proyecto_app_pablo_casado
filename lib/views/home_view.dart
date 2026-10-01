import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/data_holder.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _signOut(BuildContext context) async {
    // Cerrar sesión en Firebase Authentication
    await FirebaseAuth.instance.signOut();
    
    // Limpiar datos del DataHolder
    DataHolder().clearData();

    if (!context.mounted) return;

    // Navegar al Login y limpiar el historial de navegación
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Obtener datos del usuario actual (desde Firebase Auth o DataHolder)
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    final String userEmail = firebaseUser?.email ?? (DataHolder().userEmail.isNotEmpty ? DataHolder().userEmail : 'Invitado');
    final String userName = firebaseUser?.displayName ?? (DataHolder().userName.isNotEmpty ? DataHolder().userName : 'Usuario');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal (Home View)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
              // Tarjeta de perfil del usuario
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
              // Botón de cerrar sesión
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
