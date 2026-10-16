import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

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
  void _onMensajeRecibido(int _) {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 0;
    _inicializarEscuchaMensajes();
  }

  /// BLOQUE 4: Al destruirse la pantalla principal se cancela su listener de mensajes
  /// para evitar fugas de memoria y actualizaciones sobre un widget ya destruido.
  @override
  void dispose() {
    DataHolder.instance.perfilUsuario.removeListener(_onMensajeRecibido);
    super.dispose();
  }

  void _inicializarEscuchaMensajes() {
    final perfil = DataHolder.instance.perfilUsuario;
    perfil.addListener(_onMensajeRecibido);
    perfil.descargarMensajes();
  }

  /// BLOQUE 4: Cierra la sesión en Firebase Auth y limpia todo lo que quede abierto
  /// (cancela el StreamSubscription de Firestore mediante clearData() -> perfil.dispose()).
  Future<void> _signOut(BuildContext context) async {
    DataHolder.instance.clearData(); // Cancela las suscripciones activas y limpia memoria
    await FirebaseAuth.instance.signOut();

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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Saludo amigable
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Hola, $userName! 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColores.oscuro,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Bienvenido a tu espacio personal',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tarjeta visual moderna con los datos del perfil
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Avatar con borde exterior suave
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColores.principal,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColores.suave,
                          backgroundImage:
                              (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 48,
                                  color: AppColores.oscuro,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColores.texto,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 15,
                            color: AppColores.textoSecundario,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              userEmail,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColores.textoSecundario,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (perfilMemoria.edad != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColores.suave,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cake_outlined,
                                size: 14,
                                color: AppColores.oscuro,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${perfilMemoria.edad} años',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.oscuro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Accesos rápidos limpios y modernos
              const Text(
                'ACCESOS RÁPIDOS',
                style: AppTextos.seccion,
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/edit_profile');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColores.oscuro,
                        side: const BorderSide(color: AppColores.divisor),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadios.campo),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar Perfil'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/conversaciones');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColores.oscuro,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadios.campo),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Mis Chats'),
                    ),
                  ),
                ],
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
