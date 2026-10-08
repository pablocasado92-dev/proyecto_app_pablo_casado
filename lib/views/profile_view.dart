import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../fb_objects/perfil.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// FASE 3: VISTA CREACIÓN DE PERFIL (ProfileView)
/// ============================================================================
/// Pide edad y altura para crear por primera vez el documento de perfil del usuario.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController edadController = TextEditingController();
  final TextEditingController alturaController = TextEditingController();
  final FirebaseFirestore db = FirebaseFirestore.instance;

  @override
  void dispose() {
    edadController.dispose();
    alturaController.dispose();
    super.dispose();
  }

  Future<void> _funConfirmar() async {
    if (edadController.text.isNotEmpty && alturaController.text.isNotEmpty) {
      final perfiles = db.collection("Perfiles");
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final perfil = Perfil(
        uid: currentUser.uid,
        name: currentUser.displayName ?? "Usuario",
        edad: int.tryParse(edadController.text) ?? 18,
        altura: double.tryParse(alturaController.text.replaceAll(",", ".")) ?? 1.70,
      );

      await perfiles.doc(currentUser.uid).set(perfil.toFirestore());

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppEspacios.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppEspacios.anchoFormulario),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacios.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: AppEspacios.iconoGrande,
                        color: AppColores.principal,
                      ),
                      const SizedBox(height: AppEspacios.lg),
                      TextField(
                        controller: edadController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: "Edad",
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                      ),
                      const SizedBox(height: AppEspacios.md),
                      TextField(
                        controller: alturaController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: "Altura (m)",
                          prefixIcon: Icon(Icons.height_rounded),
                        ),
                      ),
                      const SizedBox(height: AppEspacios.lg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Salir"),
                            ),
                          ),
                          const SizedBox(width: AppEspacios.md),
                          Expanded(
                            child: FilledButton(
                              onPressed: _funConfirmar,
                              child: const Text("Confirmar"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
