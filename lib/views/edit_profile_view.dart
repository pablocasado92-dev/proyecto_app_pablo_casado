import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/data_holder.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// PANTALLA DE PERFIL Y EDICIÓN EN CUADRÍCULA (EditProfileView)
/// ============================================================================
/// Organizada con estructura en cuadrícula (`GridView`) de celdas compactas
/// para modificar los 3 campos editables: Nombre, Edad y Foto de Avatar.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _avatarUrlController;

  int? _selectedEdad;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 1;
    final perfil = DataHolder.instance.perfilUsuario;
    _nameController = TextEditingController(text: perfil.name ?? '');
    _selectedEdad = perfil.edad;
    _avatarUrlController = TextEditingController(text: perfil.urlAvatar ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  /// Guarda las modificaciones del perfil en Cloud Firestore y DataHolder
  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final String nuevoNombre = _nameController.text.trim();
    final String nuevaUrlAvatar = _avatarUrlController.text.trim();

    final String uid = DataHolder.instance.perfilUsuario.uid.isNotEmpty
        ? DataHolder.instance.perfilUsuario.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    try {
      if (uid.isNotEmpty) {
        // Actualizar en Cloud Firestore con merge
        await FirebaseFirestore.instance.collection("Perfiles").doc(uid).set({
          if (nuevoNombre.isNotEmpty) "name": nuevoNombre,
          "edad": _selectedEdad,
          "urlAvatar": nuevaUrlAvatar,
        }, SetOptions(merge: true));

        // Actualizar el perfil en memoria en DataHolder
        final perfilMemoria = DataHolder.instance.perfilUsuario;
        perfilMemoria.name = nuevoNombre;
        perfilMemoria.edad = _selectedEdad;
        perfilMemoria.urlAvatar = nuevaUrlAvatar;

        // Actualizar displayName en Firebase Auth si aplica
        await FirebaseAuth.instance.currentUser?.updateDisplayName(nuevoNombre);
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    DataHolder.instance.iBotBarIndex = 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppEspacios.md,
            vertical: AppEspacios.sm,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Vista previa de la foto de avatar actual (compacto)
                Center(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _avatarUrlController,
                    builder: (context, value, child) {
                      final String url = value.text.trim();
                      return CircleAvatar(
                        radius: 38,
                        backgroundColor: AppColores.principal,
                        backgroundImage: url.isNotEmpty
                            ? NetworkImage(url)
                            : null,
                        child: url.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 45,
                                color: Colors.white,
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppEspacios.md),

                const Text(
                  'DATOS DEL PERFIL',
                  textAlign: TextAlign.center,
                  style: AppTextos.seccion,
                ),
                const SizedBox(height: AppEspacios.sm),

                // Estructura en Cuadrícula (`GridView`) con Celdas más Pequeñas
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.35,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Tarjeta 1: Modificar Nombre
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  color: AppColores.oscuro,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Nombre',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 38,
                              child: TextFormField(
                                controller: _nameController,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Tu nombre',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Requerido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tarjeta 2: Modificar Edad con Menú Desplegable
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cake_rounded,
                                  color: AppColores.oscuro,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Edad',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 38,
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedEdad,
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Edad',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 6,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: List.generate(100, (index) {
                                  final edad = index + 1;
                                  return DropdownMenuItem<int>(
                                    value: edad,
                                    child: Text('$edad años'),
                                  );
                                }),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedEdad = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tarjeta 3: Modificar Foto de Avatar (URL)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_rounded,
                                  color: AppColores.oscuro,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Foto Avatar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 38,
                              child: TextFormField(
                                controller: _avatarUrlController,
                                style: const TextStyle(fontSize: 11),
                                decoration: InputDecoration(
                                  hintText: 'URL foto',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppEspacios.md),

                // Botón para guardar todos los cambios
                FilledButton.icon(
                  onPressed: _isSaving ? null : _guardarPerfil,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Guardar Cambios'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
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
