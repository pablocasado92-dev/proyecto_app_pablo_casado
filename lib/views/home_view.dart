import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';

/// ============================================================================
/// PANTALLA PRINCIPAL (HomeView)
/// ============================================================================
/// Panel de control del usuario autenticado. Muestra los datos de la cuenta
/// e integra la barra de navegación inferior (`InsBotBarStyle1`) con escucha activa.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 0;
    _inicializarEscuchaMensajes();
  }

  void _inicializarEscuchaMensajes() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.setOnMessageReceived((_) {
      if (mounted) {
        setState(() {});
      }
    });
    perfil.descargarMensajes();
  }

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
    final perfilMemoria = DataHolder.instance.perfilUsuario;

    final String userEmail =
        (perfilMemoria.email != null && perfilMemoria.email!.isNotEmpty)
        ? perfilMemoria.email!
        : (firebaseUser?.email ?? 'Invitado');

    final String userName =
        (perfilMemoria.name != null && perfilMemoria.name!.isNotEmpty)
        ? perfilMemoria.name!
        : (firebaseUser?.displayName ?? 'Usuario');

    final String? avatarUrl = perfilMemoria.urlAvatar;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal'),
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
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.deepPurple,
                        backgroundImage:
                            (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),
                      if (perfilMemoria.edad != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Edad: ${perfilMemoria.edad} años',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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
