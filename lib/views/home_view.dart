import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/data_holder.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';

/// ============================================================================
/// PANTALLA PRINCIPAL (HomeView)
/// ============================================================================
/// Panel de control del usuario autenticado. Muestra los datos de la cuenta
/// e integra la barra de navegación inferior (`InsBotBarStyle1`).
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  /// Realiza el cierre de sesión del usuario
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    DataHolder.instance.clearData();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    DataHolder.instance.iBotBarIndex = 0;
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    
    final String userEmail = firebaseUser?.email ?? 
        (DataHolder.instance.userEmail.isNotEmpty ? DataHolder.instance.userEmail : 'Invitado');
    final String userName = firebaseUser?.displayName ?? 
        (DataHolder.instance.userName.isNotEmpty ? DataHolder.instance.userName : 'Usuario');

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
              const SizedBox(height: 24),

              // Acceso rápido a Mensajes
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/messages'),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Ver Mis Mensajes'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),
              
              // Botón inferior para cerrar sesión
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
      bottomNavigationBar: InsBotBarStyle1(
        blBadge1: DataHolder.instance.blNotificacionesBadge,
        sBadge2: DataHolder.instance.sMessagesBadgeText,
        iBarIndex: DataHolder.instance.iBotBarIndex,
      ),
    );
  }
}
