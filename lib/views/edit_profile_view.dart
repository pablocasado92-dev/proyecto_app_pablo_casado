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
  bool _primerLogin = true;
  bool _isSaving = false;

  // Estados de la vista alimentada desde Firestore (Carga, Vacío y Error)
  bool _isLoading = true;
  String? _errorMessage;
  bool _isEmptyProfile = false;

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 1;
    final perfil = DataHolder.instance.perfilUsuario;
    _nameController = TextEditingController(text: perfil.name ?? '');
    _selectedEdad = perfil.edad;
    _primerLogin = perfil.primerLogin;
    _avatarUrlController = TextEditingController(text: perfil.urlAvatar ?? '');
    _cargarPerfilDesdeFirestore();
  }

  /// BLOQUE 4: Liberación de los controladores de texto al destruir la pantalla
  @override
  void dispose() {
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  /// Consulta el documento del perfil en Firestore usando conversión tipada (`.withConverter<Perfil>`)
  /// y gestiona los estados de carga, vacío y error.
  Future<void> _cargarPerfilDesdeFirestore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String uid = DataHolder.instance.perfilUsuario.uid.isNotEmpty
          ? DataHolder.instance.perfilUsuario.uid
          : (FirebaseAuth.instance.currentUser?.uid ?? '');

      if (uid.isEmpty) {
        setState(() {
          _isLoading = false;
          _isEmptyProfile = true;
        });
        return;
      }

      final docSnap = await FirebaseFirestore.instance
          .collection("Perfiles")
          .doc(uid)
          .withConverter<Perfil>(
            fromFirestore: Perfil.fromFirestore,
            toFirestore: (Perfil p, _) => p.toFirestore(),
          )
          .get();

      if (!mounted) return;

      final Perfil? perfilRemoto = docSnap.data();
      if (perfilRemoto == null ||
          ((perfilRemoto.name == null || perfilRemoto.name!.isEmpty) &&
              perfilRemoto.edad == null)) {
        setState(() {
          _isLoading = false;
          _isEmptyProfile = true;
        });
      } else {
        DataHolder.instance.perfilUsuario.name = perfilRemoto.name;
        DataHolder.instance.perfilUsuario.edad = perfilRemoto.edad;
        DataHolder.instance.perfilUsuario.urlAvatar = perfilRemoto.urlAvatar;
        DataHolder.instance.perfilUsuario.primerLogin =
            perfilRemoto.primerLogin;

        _nameController.text = perfilRemoto.name ?? '';
        _avatarUrlController.text = perfilRemoto.urlAvatar ?? '';
        setState(() {
          _selectedEdad = perfilRemoto.edad;
          _primerLogin = perfilRemoto.primerLogin;
          _isEmptyProfile = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar el perfil desde Firestore: $e';
      });
    }
  }

  /// Guarda las modificaciones del perfil en Cloud Firestore usando `.withConverter<Perfil>`
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
        final perfilMemoria = DataHolder.instance.perfilUsuario;
        perfilMemoria.name = nuevoNombre;
        perfilMemoria.edad = _selectedEdad;
        perfilMemoria.urlAvatar = nuevaUrlAvatar;
        perfilMemoria.primerLogin = _primerLogin;

        // Escritura con conversión tipada (.withConverter<Perfil>)
        await FirebaseFirestore.instance
            .collection("Perfiles")
            .doc(uid)
            .withConverter<Perfil>(
              fromFirestore: Perfil.fromFirestore,
              toFirestore: (Perfil p, _) => p.toFirestore(),
            )
            .set(perfilMemoria, SetOptions(merge: true));

        // Actualizar displayName en Firebase Auth si aplica
        await FirebaseAuth.instance.currentUser?.updateDisplayName(nuevoNombre);
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _isEmptyProfile = false;
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
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SafeArea(
        child: _isLoading
            // 1. ESTADO DE CARGA
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColores.oscuro),
                    SizedBox(height: 12),
                    Text(
                      'Cargando datos del perfil...',
                      style: TextStyle(color: AppColores.textoSecundario),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
            // 2. ESTADO DE ERROR
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 56,
                        color: AppColores.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColores.texto),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _cargarPerfilDesdeFirestore,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            // 3. CONTENIDO PRINCIPAL EN CUADRÍCULA (con aviso si está en ESTADO VACÍO)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppEspacios.md,
                  vertical: AppEspacios.sm,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isEmptyProfile)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColores.suave,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColores.oscuro,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tu perfil aún no tiene datos guardados en Firestore. Completa la cuadrícula para inicializarlo.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColores.oscuro,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 6,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Tarjeta 4: Configurar y volver a ver Onboarding
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
                                        Icons.slideshow_rounded,
                                        color: AppColores.oscuro,
                                        size: 20,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Onboarding',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Switch(
                                        value: _primerLogin,
                                        activeTrackColor: AppColores.oscuro,
                                        onChanged: (val) {
                                          setState(() {
                                            _primerLogin = val;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: AppColores.oscuro,
                                          size: 24,
                                        ),
                                        tooltip: 'Ver Onboarding ahora',
                                        onPressed: () {
                                          DataHolder
                                                  .instance
                                                  .perfilUsuario
                                                  .primerLogin =
                                              true;
                                          Navigator.pushNamed(
                                            context,
                                            '/onboarding',
                                          );
                                        },
                                      ),
                                    ],
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
