import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../fb_objects/perfil.dart';
import 'login_screen.dart';
import 'profile_view.dart';

/// ============================================================================
/// FASE 3: PUERTA DE ACCESO / CONTROL DE PERFIL (HomeProfileGate)
/// ============================================================================
/// Evalúa el perfil del usuario autenticado antes de mostrar la pantalla principal.
/// Si el usuario no existe en Firestore o no ha completado su perfil, lo redirige
/// automáticamente a la pantalla para crear su perfil (ProfileView).
class HomeProfileGate extends StatefulWidget {
  const HomeProfileGate({super.key, required this.homeBuilder});

  final WidgetBuilder homeBuilder;

  @override
  State<HomeProfileGate> createState() => _HomeProfileGateState();
}

class _HomeProfileGateState extends State<HomeProfileGate> {
  late Future<_HomeDestination> _destination;

  @override
  void initState() {
    super.initState();
    _destination = _loadProfile();
  }

  Future<_HomeDestination> _loadProfile() async {
    // Comprobar la sesión activa en Firebase Authentication
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return _HomeDestination.login;

    // Obtener el perfil desde la colección "Perfiles" de Firestore
    final doc = await FirebaseFirestore.instance
        .collection('Perfiles')
        .doc(user.uid)
        .withConverter<Perfil>(
          fromFirestore: Perfil.fromFirestore,
          toFirestore: (perfil, _) => perfil.toFirestore(),
        )
        .get();

    final perfil = doc.data();
    if (perfil == null) return _HomeDestination.profile;

    // Guardar el perfil en el DataHolder global
    DataHolder.instance.perfilUsuario = perfil;
    await perfil.descargarMensajes();

    // Actualizar el número de mensajes no leídos para el badge
    DataHolder.instance.sMessagesBadgeText = perfil.mensajes
        .where((mensaje) => !mensaje.leido)
        .length
        .toString();

    return _HomeDestination.home;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeDestination>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar el perfil.'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _destination = _loadProfile()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        switch (snapshot.data!) {
          case _HomeDestination.login:
            return const LoginScreen();
          case _HomeDestination.profile:
            return const ProfileView();
          case _HomeDestination.home:
            return widget.homeBuilder(context);
        }
      },
    );
  }
}

enum _HomeDestination { login, profile, home }
