import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/data_holder.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// VISTA EN CUADRÍCULA DE PERFILES EN CONVERSACIÓN (EditProfileView)
/// ============================================================================
/// Muestra los perfiles de los contactos con los que el usuario tiene conversaciones
/// iniciadas en una estructura en cuadrícula (`GridView.builder`), con indicador
/// de conexión en la esquina superior izquierda, control de estados (Carga,
/// Vacío y Error) y modal para la edición del propio perfil.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  // Lista de perfiles de contactos con los que existen conversaciones
  List<Perfil> _perfiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  void _onMensajesActualizados(int _) {
    // Si llegan nuevos mensajes en tiempo real, recargar la lista de perfiles
    _cargarPerfilesDesdeFirestore();
  }

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 1;
    // Escuchar cambios en los mensajes del usuario para refrescar la cuadrícula en vivo
    DataHolder.instance.perfilUsuario.addListener(_onMensajesActualizados);
    _cargarPerfilesDesdeFirestore();
  }

  @override
  void dispose() {
    DataHolder.instance.perfilUsuario.removeListener(_onMensajesActualizados);
    super.dispose();
  }

  /// Consulta la colección "Perfiles" en Cloud Firestore utilizando conversión tipada
  /// con `.withConverter<Perfil>` y filtra ÚNICAMENTE aquellos perfiles de personas
  /// con las que el usuario actual tenga conversaciones iniciadas.
  Future<void> _cargarPerfilesDesdeFirestore() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("Perfiles")
          .withConverter<Perfil>(
            fromFirestore: Perfil.fromFirestore,
            toFirestore: (Perfil p, _) => p.toFirestore(),
          )
          .get();

      if (!mounted) return;

      final List<Perfil> todosLosPerfiles = snapshot.docs
          .map((d) => d.data())
          .toList();

      final String currentUid =
          (FirebaseAuth.instance.currentUser?.uid ??
                  DataHolder.instance.perfilUsuario.uid)
              .trim()
              .toLowerCase();
      final String currentEmail =
          (FirebaseAuth.instance.currentUser?.email ??
                  DataHolder.instance.perfilUsuario.email ??
                  '')
              .trim()
              .toLowerCase();

      // Recopilar los UIDs/correos de todos los contactos con conversaciones iniciadas
      final Set<String> contactosConChat = {};

      for (final m in DataHolder.instance.perfilUsuario.mensajes) {
        final rem = (m.remitenteUID ?? '').trim().toLowerCase();
        final dest = (m.destinatarioUID ?? '').trim().toLowerCase();

        final bool yoSoyRemitente =
            (currentUid.isNotEmpty && rem == currentUid) ||
            (currentEmail.isNotEmpty && rem == currentEmail);
        final bool yoSoyDestinatario =
            (currentUid.isNotEmpty && dest == currentUid) ||
            (currentEmail.isNotEmpty && dest == currentEmail);

        if (yoSoyRemitente && dest.isNotEmpty) {
          contactosConChat.add(dest);
        } else if (yoSoyDestinatario && rem.isNotEmpty) {
          contactosConChat.add(rem);
        }
      }

      for (final c in DataHolder.instance.getConversaciones()) {
        final key = c.contactoUidOrEmail.trim().toLowerCase();
        if (key.isNotEmpty) {
          contactosConChat.add(key);
        }
      }

      // Filtrar únicamente los perfiles de personas con las que hay conversación iniciada
      final List<Perfil> filtrados = todosLosPerfiles.where((p) {
        final pUid = p.uid.trim().toLowerCase();
        final pEmail = (p.email ?? '').trim().toLowerCase();

        // No incluir al propio usuario en la cuadrícula de contactos
        if (pUid == currentUid ||
            (currentEmail.isNotEmpty && pEmail == currentEmail)) {
          return false;
        }

        return contactosConChat.contains(pUid) ||
            (pEmail.isNotEmpty && contactosConChat.contains(pEmail));
      }).toList();

      // Para cualquier contacto de un chat activo que no tenga documento en Perfiles,
      // generamos un Perfil de respaldo para que aparezca correctamente en la cuadrícula
      for (final key in contactosConChat) {
        if (key == currentUid ||
            (currentEmail.isNotEmpty && key == currentEmail)) {
          continue;
        }
        final bool yaExiste = filtrados.any(
          (p) =>
              p.uid.trim().toLowerCase() == key ||
              (p.email ?? '').trim().toLowerCase() == key,
        );

        if (!yaExiste) {
          final bool esEmail = key.contains('@');
          filtrados.add(
            Perfil(
              uid: key,
              name: esEmail ? key.split('@').first : key,
              email: esEmail ? key : null,
              conectado: false,
            ),
          );
        }
      }

      // Ordenar alfabéticamente por nombre
      filtrados.sort((a, b) {
        final nameA = a.name?.toLowerCase() ?? '';
        final nameB = b.name?.toLowerCase() ?? '';
        return nameA.compareTo(nameB);
      });

      setState(() {
        _perfiles = filtrados;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar la colección de perfiles: $e';
      });
    }
  }

  /// Despliega un panel modal inferior (BottomSheet) para editar los campos del
  /// perfil del usuario actualmente autenticado y sincronizarlos con Firestore.
  void _mostrarModalEdicionPerfil() {
    final perfilActual = DataHolder.instance.perfilUsuario;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: perfilActual.name ?? '');
    String currentAvatarUrl = perfilActual.urlAvatar ?? '';
    XFile? nuevaImagenSeleccionada;
    Uint8List? previewBytes;
    // Rango de edad permitido: 16 a 99 años. Si el valor actual está fuera, ajustar a null.
    int? selectedEdad =
        (perfilActual.edad != null &&
            perfilActual.edad! >= 16 &&
            perfilActual.edad! <= 99)
        ? perfilActual.edad
        : null;
    bool primerLogin = perfilActual.primerLogin;
    bool isSavingModal = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadios.cabecera),
        ),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Función auxiliar para seleccionar imagen desde Cámara o Galería
            Future<void> seleccionarImagen(ImageSource source) async {
              Navigator.pop(ctx); // Cierra el selector de origen
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );

                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  setModalState(() {
                    nuevaImagenSeleccionada = picked;
                    previewBytes = bytes;
                  });
                }
              } catch (e) {
                debugPrint("Error al seleccionar imagen: $e");
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo acceder a la ${source == ImageSource.camera ? "cámara" : "galería"}. Revisa los permisos de la aplicación.',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }

            // Muestra menú de opciones: Cámara o Galería
            void mostrarOpcionesOrigen() {
              showModalBottomSheet(
                context: modalContext,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadios.cabecera),
                  ),
                ),
                builder: (pickerCtx) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Seleccionar Foto de Perfil',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColores.oscuro,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColores.oscuro,
                            ),
                            title: const Text('Tomar foto con la cámara'),
                            onTap: () => seleccionarImagen(ImageSource.camera),
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.photo_library_rounded,
                              color: AppColores.oscuro,
                            ),
                            title: const Text('Elegir de la galería'),
                            onTap: () => seleccionarImagen(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppEspacios.md,
                right: AppEspacios.md,
                top: AppEspacios.md,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Barra decorativa superior del modal
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColores.divisor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Título del modal
                      const Row(
                        children: [
                          Icon(
                            Icons.manage_accounts_rounded,
                            color: AppColores.oscuro,
                            size: 26,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Editar Mi Perfil',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColores.oscuro,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Selector visual de Avatar (Cámara / Galería con vista previa)
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: AppColores.suave,
                              backgroundImage: previewBytes != null
                                  ? MemoryImage(previewBytes!)
                                  : (currentAvatarUrl.isNotEmpty
                                        ? NetworkImage(currentAvatarUrl)
                                              as ImageProvider
                                        : null),
                              onBackgroundImageError:
                                  currentAvatarUrl.isNotEmpty
                                  ? (exception, stackTrace) {
                                      debugPrint("Aviso Web/CORS: $exception");
                                    }
                                  : null,
                              child:
                                  (previewBytes == null &&
                                      currentAvatarUrl.isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: AppColores.oscuro,
                                    )
                                  : null,
                            ),
                            Material(
                              color: AppColores.oscuro,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: isSavingModal
                                    ? null
                                    : mostrarOpcionesOrigen,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton.icon(
                          onPressed: isSavingModal
                              ? null
                              : mostrarOpcionesOrigen,
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Cambiar Foto',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Campo: Nombre
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Por favor ingresa tu nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Campo: Edad con Dropdown
                      DropdownButtonFormField<int>(
                        initialValue: selectedEdad,
                        decoration: InputDecoration(
                          labelText: 'Edad',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        items: List.generate(84, (i) {
                          final e = 16 + i; // Rango de 16 a 99 años
                          return DropdownMenuItem<int>(
                            value: e,
                            child: Text('$e años'),
                          );
                        }),
                        onChanged: (val) {
                          setModalState(() {
                            selectedEdad = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Configuración de Onboarding
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColores.suave,
                          borderRadius: BorderRadius.circular(AppRadios.campo),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.slideshow_rounded,
                              color: AppColores.oscuro,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Mostrar bienvenida (Onboarding)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColores.oscuro,
                                ),
                              ),
                            ),
                            Switch(
                              value: primerLogin,
                              activeTrackColor: AppColores.oscuro,
                              onChanged: (val) {
                                setModalState(() {
                                  primerLogin = val;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: AppColores.oscuro,
                              ),
                              tooltip: 'Ver Onboarding ahora',
                              onPressed: () {
                                DataHolder.instance.perfilUsuario.primerLogin =
                                    true;
                                Navigator.pushNamed(context, '/onboarding');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botón: Guardar Cambios
                      FilledButton.icon(
                        onPressed: isSavingModal
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() {
                                  isSavingModal = true;
                                });

                                final String uid =
                                    FirebaseAuth.instance.currentUser?.uid ??
                                    DataHolder.instance.perfilUsuario.uid;
                                final nuevoNombre = nameController.text.trim();

                                try {
                                  if (uid.isNotEmpty) {
                                    // 1. Si se eligió una foto nueva, subirla a Firebase Storage
                                    if (nuevaImagenSeleccionada != null) {
                                      final urlSubida = await DataHolder
                                          .instance
                                          .storageAdmin
                                          .subirAvatar(
                                            nuevaImagenSeleccionada!,
                                            uid,
                                          );
                                      if (urlSubida.isNotEmpty) {
                                        currentAvatarUrl = urlSubida;
                                      }
                                    }

                                    // 2. Actualizar perfil local y en Firestore
                                    final perfilMemoria =
                                        DataHolder.instance.perfilUsuario;
                                    perfilMemoria.name = nuevoNombre;
                                    perfilMemoria.edad = selectedEdad;
                                    perfilMemoria.urlAvatar = currentAvatarUrl;
                                    perfilMemoria.primerLogin = primerLogin;

                                    // Guardado en Firestore con .withConverter<Perfil>
                                    await FirebaseFirestore.instance
                                        .collection("Perfiles")
                                        .doc(uid)
                                        .withConverter<Perfil>(
                                          fromFirestore: Perfil.fromFirestore,
                                          toFirestore: (Perfil p, _) =>
                                              p.toFirestore(),
                                        )
                                        .set(
                                          perfilMemoria,
                                          SetOptions(merge: true),
                                        );

                                    await FirebaseAuth.instance.currentUser
                                        ?.updateDisplayName(nuevoNombre);
                                  }

                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                  }
                                  _cargarPerfilesDesdeFirestore();

                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Perfil actualizado correctamente',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint("Error guardando perfil: $e");
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error al actualizar perfil: $e',
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } finally {
                                  setModalState(() {
                                    isSavingModal = false;
                                  });
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColores.oscuro,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        icon: isSavingModal
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          isSavingModal ? 'Guardando...' : 'Guardar Cambios',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DataHolder.instance.iBotBarIndex = 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar perfiles',
            onPressed: _cargarPerfilesDesdeFirestore,
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Editar mi perfil',
            onPressed: _mostrarModalEdicionPerfil,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            // ESTADO 1: CARGA
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColores.principal),
                    SizedBox(height: 12),
                    Text(
                      'Cargando perfiles...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
            // ESTADO 2: ERROR
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacios.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColores.texto,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _cargarPerfilesDesdeFirestore,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColores.oscuro,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : _perfiles.isEmpty
            // ESTADO 3: VACÍO
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacios.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        size: 56,
                        color: AppColores.divisor,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Aún no tienes chats iniciados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColores.oscuro,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Aquí se mostrarán los perfiles de los contactos con quienes mantengas conversaciones activas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _mostrarModalEdicionPerfil,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColores.oscuro,
                          side: const BorderSide(color: AppColores.principal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text('Configurar Mi Perfil'),
                      ),
                    ],
                  ),
                ),
              )
            // ESTADO 4: CUADRÍCULA CON PERFILES DE CONTACTOS EN CHAT
            : RefreshIndicator(
                onRefresh: _cargarPerfilesDesdeFirestore,
                child: Column(
                  children: [
                    // Cabecera informativa sobre la cuadrícula
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Contactos Activos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.oscuro,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_perfiles.length} contactos con chat activo',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColores.textoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _mostrarModalEdicionPerfil,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColores.oscuro,
                              side: const BorderSide(
                                color: AppColores.principal,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'Mi Perfil',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // GridView con cada perfil de contacto con conversación
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _cargarPerfilesDesdeFirestore,
                        child: GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.70,
                              ),
                          itemCount: _perfiles.length,
                          itemBuilder: (context, index) {
                            final perfil = _perfiles[index];

                            // Criterio de presencia en línea:
                            // El contacto se muestra 'En línea' si su bandera 'conectado' es true,
                            // cuenta con timestamp de última interacción (heartbeat) y han transcurrido
                            // menos de 5 minutos desde la misma. Si pasan 5 minutos sin actividad
                            // o se cerró la aplicación de forma imprevista, pasa a 'Desconectado'.
                            final DateTime ahora = DateTime.now();
                            final DateTime? ultima = perfil.ultimaConexion
                                ?.toDate();
                            final bool estaConectado =
                                perfil.conectado &&
                                ultima != null &&
                                ahora.difference(ultima).inMinutes < 5;

                            final String nombre =
                                (perfil.name != null && perfil.name!.isNotEmpty)
                                ? perfil.name!
                                : (perfil.email ?? 'Contacto');
                            final String? avatarUrl = perfil.urlAvatar;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: AppColores.divisor,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Fila superior: Badge de conexión (izquierda)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Esquina superior izquierda: Badge En línea / Desconectado
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: estaConectado
                                                ? const Color.fromARGB(
                                                    255,
                                                    232,
                                                    248,
                                                    235,
                                                  )
                                                : const Color.fromARGB(
                                                    255,
                                                    240,
                                                    240,
                                                    240,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: estaConectado
                                                  ? Colors.green.shade400
                                                  : Colors.grey.shade400,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: estaConectado
                                                      ? Colors.green
                                                      : Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                estaConectado
                                                    ? 'En línea'
                                                    : 'Desconectado',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: estaConectado
                                                      ? Colors.green.shade800
                                                      : Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 1),
                                      ],
                                    ),

                                    // Avatar del contacto
                                    CircleAvatar(
                                      radius: 34,
                                      backgroundColor: AppColores.suave,
                                      backgroundImage:
                                          (avatarUrl != null &&
                                              avatarUrl.isNotEmpty)
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      onBackgroundImageError:
                                          (avatarUrl != null &&
                                              avatarUrl.isNotEmpty)
                                          ? (exception, stackTrace) {
                                              debugPrint(
                                                "Aviso Web/CORS en perfil: $exception",
                                              );
                                            }
                                          : null,
                                      child:
                                          (avatarUrl == null ||
                                              avatarUrl.isEmpty)
                                          ? const Icon(
                                              Icons.person_rounded,
                                              size: 34,
                                              color: AppColores.oscuro,
                                            )
                                          : null,
                                    ),

                                    // Nombre del contacto
                                    Text(
                                      nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColores.texto,
                                      ),
                                    ),

                                    // Edad o correo del contacto
                                    if (perfil.edad != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColores.suave,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${perfil.edad} años',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColores.oscuro,
                                          ),
                                        ),
                                      )
                                    else if (perfil.email != null)
                                      Text(
                                        perfil.email!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColores.textoSecundario,
                                        ),
                                      ),

                                    // Botón de acción: Chatear
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          final String destino =
                                              perfil.uid.isNotEmpty
                                              ? perfil.uid
                                              : (perfil.email ?? '');
                                          Navigator.pushNamed(
                                            context,
                                            '/chat',
                                            arguments: destino,
                                          );
                                        },
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          backgroundColor: AppColores.oscuro,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Chatear',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
