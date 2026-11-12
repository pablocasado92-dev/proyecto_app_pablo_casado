import 'dart:convert';

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
/// iniciadas o permite descubrir nuevos usuarios cercanos en un radio de 25 km.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  // Lista de contactos con los que existen conversaciones activas
  List<Perfil> _perfilesContactos = [];

  // ============================================================================
  // FILTROS DE COMUNIDAD:
  // 0: Mis Contactos (Contactos con chat activo)
  // 1: Descubrir cercanos (Sin conversación, radio <= 25 km)
  // ============================================================================
  int _filtroActivo = 0;
  List<PerfilDistanciaDTO> _perfilesDescubrir = [];
  bool _cargandoFiltro = true;
  String? _errorFiltro;
  bool _obteniendoUbicacion = false;

  void _onMensajesActualizados(int _) {
    _cargarContactosConChat();
  }

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 1;
    DataHolder.instance.perfilUsuario.addListener(_onMensajesActualizados);
    _cargarContactosYFiltroInicial();
  }

  @override
  void dispose() {
    DataHolder.instance.perfilUsuario.removeListener(_onMensajesActualizados);
    super.dispose();
  }

  Future<void> _cargarContactosYFiltroInicial() async {
    await _cargarContactosConChat();
    _cambiarFiltro(_filtroActivo);
  }

  /// Carga los contactos con quienes el usuario mantiene conversaciones activas
  Future<void> _cargarContactosConChat() async {
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

      final List<Perfil> filtrados = todosLosPerfiles.where((p) {
        final pUid = p.uid.trim().toLowerCase();
        final pEmail = (p.email ?? '').trim().toLowerCase();

        if (pUid == currentUid ||
            (currentEmail.isNotEmpty && pEmail == currentEmail)) {
          return false;
        }

        return contactosConChat.contains(pUid) ||
            (pEmail.isNotEmpty && contactosConChat.contains(pEmail));
      }).toList();

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

      filtrados.sort((a, b) {
        final nameA = a.name?.toLowerCase() ?? '';
        final nameB = b.name?.toLowerCase() ?? '';
        return nameA.compareTo(nameB);
      });

      if (!mounted) return;
      setState(() {
        _perfilesContactos = filtrados;
      });
    } catch (e) {
      debugPrint("Aviso al cargar contactos con chat: $e");
    }
  }

  /// Despliega un panel modal inferior (BottomSheet) para editar los campos del
  /// perfil del usuario actualmente autenticado y sincronizarlos con Firestore.
  void _mostrarModalEdicionPerfil() {
    final perfilActual = DataHolder.instance.perfilUsuario;
    final String uid =
        FirebaseAuth.instance.currentUser?.uid ?? perfilActual.uid;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: perfilActual.name ?? '');
    String currentAvatarUrl = perfilActual.urlAvatar ?? '';
    String? currentAvatarBase64 = perfilActual.avatarBase64;
    XFile? nuevaImagenSeleccionada;
    Uint8List? previewBytes;
    String estadoIsolate = '';
    bool isProcessingIsolate = false;
    // Rango de edad permitido: 16 a 99 años. Si el valor actual está fuera, ajustar a null.
    int? selectedEdad =
        (perfilActual.edad != null &&
            perfilActual.edad! >= 16 &&
            perfilActual.edad! <= 99)
        ? perfilActual.edad
        : null;
    bool primerLogin = perfilActual.primerLogin;
    GeoPoint? currentPosicion = perfilActual.posicion;
    Timestamp? currentFechaPosicion = perfilActual.fechaPosicion;
    bool isLocating = false;
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
            // Función auxiliar para seleccionar imagen desde Cámara o Galería con procesamiento en Isolate
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
                  setModalState(() {
                    isProcessingIsolate = true;
                    estadoIsolate = 'Preparando imagen...';
                  });

                  // PSP RA2.c / RA2.e: Compresión asíncrona en ISOLATE comunicando progreso
                  final procesada = await DataHolder.instance.storageAdmin
                      .procesarYComprimirEnIsolate(
                        picked,
                        onProgreso: (msg) {
                          setModalState(() {
                            estadoIsolate = msg;
                          });
                        },
                      );

                  setModalState(() {
                    nuevaImagenSeleccionada = picked;
                    previewBytes = procesada.bytesComprimidos;
                    currentAvatarBase64 = procesada.base64String;
                    isProcessingIsolate = false;
                    estadoIsolate =
                        'Comprimido con éxito (${procesada.tamanoKb.toStringAsFixed(1)} KB en Isolate)';
                  });
                }
              } catch (e) {
                setModalState(() {
                  isProcessingIsolate = false;
                  estadoIsolate = '';
                });
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
                                  : (currentAvatarBase64 != null &&
                                            currentAvatarBase64!.isNotEmpty
                                        ? MemoryImage(
                                            base64Decode(currentAvatarBase64!),
                                          )
                                        : (currentAvatarUrl.isNotEmpty
                                              ? NetworkImage(currentAvatarUrl)
                                                    as ImageProvider
                                              : null)),
                              onBackgroundImageError:
                                  currentAvatarUrl.isNotEmpty
                                  ? (exception, stackTrace) {
                                      debugPrint("Aviso Web/CORS: $exception");
                                    }
                                  : null,
                              child:
                                  (previewBytes == null &&
                                      (currentAvatarBase64 == null ||
                                          currentAvatarBase64!.isEmpty) &&
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
                                onTap: (isSavingModal || isProcessingIsolate)
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
                      if (isProcessingIsolate || estadoIsolate.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColores.suave,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColores.divisor),
                          ),
                          child: Column(
                            children: [
                              if (isProcessingIsolate) ...[
                                const LinearProgressIndicator(
                                  backgroundColor: AppColores.suave,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColores.principal,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                estadoIsolate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.oscuro,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton.icon(
                          onPressed: (isSavingModal || isProcessingIsolate)
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
                      const SizedBox(height: 12),

                      // BLOQUE 5: Bloque de Geolocalización (Dónde estoy)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColores.suave,
                          borderRadius: BorderRadius.circular(AppRadios.campo),
                          border: Border.all(
                            color: AppColores.divisor,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColores.principal,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Ubicación actual (GPS)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.oscuro,
                                    ),
                                  ),
                                ),
                                if (currentPosicion != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Guardada',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (currentPosicion != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'Lat: ${currentPosicion!.latitude.toStringAsFixed(5)}, '
                                  'Lng: ${currentPosicion!.longitude.toStringAsFixed(5)}'
                                  '${currentFechaPosicion != null ? ' (${currentFechaPosicion!.toDate().hour.toString().padLeft(2, '0')}:${currentFechaPosicion!.toDate().minute.toString().padLeft(2, '0')})' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColores.texto,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'Sin ubicación registrada. Pulsa para capturar tus coordenadas actuales.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColores.textoSecundario,
                                  ),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: (isSavingModal || isLocating)
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        isLocating = true;
                                      });

                                      final resultado = await DataHolder
                                          .instance
                                          .locationAdmin
                                          .obtenerPosicionActual();

                                      setModalState(() {
                                        isLocating = false;
                                        if (resultado.isSuccess &&
                                            resultado.geoPoint != null) {
                                          currentPosicion = resultado.geoPoint;
                                          currentFechaPosicion =
                                              Timestamp.now();
                                        }
                                      });

                                      if (!modalContext.mounted) return;

                                      if (resultado.isSuccess) {
                                        ScaffoldMessenger.of(modalContext)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Ubicación GPS obtenida con éxito.',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                      } else {
                                        ScaffoldMessenger.of(modalContext)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  resultado.mensaje ?? 'No se pudo obtener la ubicación.',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                      }
                                    },
                              icon: isLocating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColores.principal,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location_rounded,
                                      size: 16,
                                    ),
                              label: Text(
                                isLocating
                                    ? 'Obteniendo GPS...'
                                    : (currentPosicion == null
                                          ? 'Capturar ubicación actual'
                                          : 'Actualizar ubicación'),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColores.oscuro,
                                side: const BorderSide(
                                  color: AppColores.principal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadios.campo,
                                  ),
                                ),
                              ),
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
                                    perfilMemoria.avatarBase64 =
                                        currentAvatarBase64;
                                    perfilMemoria.primerLogin = primerLogin;
                                    perfilMemoria.posicion = currentPosicion;
                                    perfilMemoria.fechaPosicion =
                                        currentFechaPosicion;
                                    perfilMemoria.conectado = true; // El usuario está activo e interactuando en la app

                                    // BLOQUE 3 (0486 RA4.f): Modificar documento propio con update()
                                    final docRef = FirebaseFirestore.instance
                                        .collection("Perfiles")
                                        .doc(uid);
                                    final docSnap = await docRef.get();
                                    if (docSnap.exists) {
                                      await docRef.update(
                                        perfilMemoria.toFirestore(),
                                      );
                                    } else {
                                      await docRef.set(
                                        perfilMemoria.toFirestore(),
                                      );
                                    }

                                    await FirebaseAuth.instance.currentUser
                                        ?.updateDisplayName(nuevoNombre);
                                  }

                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                  }
                                  await _cargarContactosConChat();
                                  _cambiarFiltro(_filtroActivo);

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
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: isSavingModal
                            ? null
                            : () => _confirmarEliminarPerfil(uid),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'Eliminar mi perfil y cuenta',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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

  /// BLOQUE 3 (0486 RA4.f): Borrar documento propio de Firestore con confirmación
  /// modal y tratamiento visual de errores si la operación falla.
  void _confirmarEliminarPerfil(String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            SizedBox(width: 8),
            Text('Eliminar perfil'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar permanentemente tu perfil? '
          'Se borrarán todos tus datos en Cloud Firestore y se cerrará tu sesión. Esta acción es irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              try {
                // 1. Eliminar documento propio en Firestore (0486 RA4.f)
                await FirebaseFirestore.instance
                    .collection("Perfiles")
                    .doc(uid)
                    .delete();

                // 2. Limpiar memoria y cerrar sesión
                await DataHolder.instance.detenerPresencia();
                DataHolder.instance.clearData();
                await FirebaseAuth.instance.signOut();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tu perfil ha sido eliminado correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar perfil en Firestore: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GESTIÓN DE FILTROS: 0 (Mis Contactos) y 1 (Descubrir cercanos <= 25 km)
  // ============================================================================

  Future<void> _cambiarFiltro(int indiceFiltro) async {
    if (!mounted) return;
    setState(() {
      _filtroActivo = indiceFiltro;
      _cargandoFiltro = true;
      _errorFiltro = null;
    });

    if (indiceFiltro == 0) {
      await _cargarContactosConChat();
      if (!mounted) return;
      setState(() {
        _cargandoFiltro = false;
      });
    } else {
      await _cargarDescubrirCercanos();
    }
  }

  /// Carga usuarios cercanos en un radio de 25 km con los que NO hay conversación previa
  Future<void> _cargarDescubrirCercanos() async {
    final miPos = DataHolder.instance.perfilUsuario.posicion;
    if (miPos == null) {
      if (!mounted) return;
      setState(() {
        _perfilesDescubrir = [];
        _cargandoFiltro = false;
        _errorFiltro = null;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("Perfiles")
          .withConverter<Perfil>(
            fromFirestore: Perfil.fromFirestore,
            toFirestore: (Perfil p, _) => p.toFirestore(),
          )
          .get();

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

      // Recopilar contactos con conversaciones activas
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
        if (key.isNotEmpty) contactosConChat.add(key);
      }

      final List<PerfilDistanciaDTO> cercanos = [];
      for (final doc in snapshot.docs) {
        final p = doc.data();
        final pUid = p.uid.trim().toLowerCase();
        final pEmail = (p.email ?? '').trim().toLowerCase();

        // 1. Descartar al propio usuario actual
        if (pUid == currentUid ||
            (currentEmail.isNotEmpty && pEmail == currentEmail)) {
          continue;
        }

        // 2. Descartar usuarios con los que YA existe conversación
        if (contactosConChat.contains(pUid) ||
            (pEmail.isNotEmpty && contactosConChat.contains(pEmail))) {
          continue;
        }

        // 3. Debe tener coordenadas registradas
        if (p.posicion == null) continue;

        // 4. Calcular distancia geodésica mediante Haversine
        final distKm = LocationAdmin.calcularDistanciaHaversine(
          miPos.latitude,
          miPos.longitude,
          p.posicion!.latitude,
          p.posicion!.longitude,
        );

        // 5. Criterio: radio de 25 km
        if (distKm <= 25.0) {
          cercanos.add(PerfilDistanciaDTO(perfil: p, distanciaKm: distKm));
        }
      }

      // Ordenar de menor a mayor distancia
      cercanos.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));

      if (!mounted) return;
      setState(() {
        _perfilesDescubrir = cercanos;
        _cargandoFiltro = false;
        _errorFiltro = null;
      });
    } catch (e) {
      debugPrint("Error al buscar usuarios cercanos: $e");
      if (!mounted) return;
      setState(() {
        _cargandoFiltro = false;
        _errorFiltro = 'Error al buscar usuarios cercanos: $e';
      });
    }
  }

  /// Obtiene la ubicación GPS actual del dispositivo y recarga el filtro Descubrir
  Future<void> _obtenerUbicacionYRecargar() async {
    setState(() {
      _obteniendoUbicacion = true;
    });

    try {
      final locAdmin = DataHolder.instance.locationAdmin;
      final result = await locAdmin.obtenerPosicionActual();
      if (!result.isSuccess || result.geoPoint == null) {
        if (!mounted) return;
        setState(() {
          _obteniendoUbicacion = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.mensaje ?? 'No se pudo obtener la ubicación GPS.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final geo = result.geoPoint!;
      final ahora = Timestamp.now();

      DataHolder.instance.perfilUsuario.posicion = geo;
      DataHolder.instance.perfilUsuario.fechaPosicion = ahora;

      final uid =
          FirebaseAuth.instance.currentUser?.uid ??
          DataHolder.instance.perfilUsuario.uid;
      if (uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection("Perfiles").doc(uid).set({
          "posicion": geo,
          "fechaPosicion": ahora,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() {
        _obteniendoUbicacion = false;
      });
      _cambiarFiltro(1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _obteniendoUbicacion = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo obtener la ubicación: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _sembrarDatosPrueba() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verificando y sembrando perfiles de prueba en Firestore...',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      final count = await DataHolder.instance.queriesAdmin
          .sembrar20PerfilesPrueba(forzar: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Colección Perfiles lista con $count documentos.'),
          backgroundColor: Colors.green,
        ),
      );
      await _cargarContactosConChat();
      _cambiarFiltro(_filtroActivo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sembrar datos: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================================
  // WIDGETS DE LA VISTA COMUNIDAD
  // ============================================================================

  Widget _buildBarraFiltros() {
    final List<({int id, String titulo, IconData icono})> filtros = [
      (
        id: 0,
        titulo: 'Mis Contactos (${_perfilesContactos.length})',
        icono: Icons.chat_bubble_outline_rounded,
      ),
      (id: 1, titulo: 'Descubrir (< 25 km)', icono: Icons.near_me_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: filtros.map((f) {
          final bool seleccionado = _filtroActivo == f.id;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              selected: seleccionado,
              showCheckmark: false,
              avatar: Icon(
                f.icono,
                size: 14,
                color: seleccionado ? Colors.white : AppColores.oscuro,
              ),
              label: Text(
                f.titulo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                  color: seleccionado ? Colors.white : AppColores.texto,
                ),
              ),
              backgroundColor: AppColores.suave,
              selectedColor: AppColores.oscuro,
              side: BorderSide(
                color: seleccionado ? AppColores.oscuro : AppColores.divisor,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => _cambiarFiltro(f.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Tarjeta para usuarios en «Mis Contactos»
  Widget _buildCardContacto(Perfil perfil) {
    final bool estaConectado = perfil.conectado;

    final String nombre = (perfil.name != null && perfil.name!.isNotEmpty)
        ? perfil.name!
        : (perfil.email ?? 'Contacto');
    final String? avatarUrl = perfil.urlAvatar;
    final String? avatarBase64 = perfil.avatarBase64;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColores.divisor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Fila superior: Badge de conexión (izquierda) y edad (derecha)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: estaConectado
                        ? const Color.fromARGB(255, 232, 248, 235)
                        : const Color.fromARGB(255, 240, 240, 240),
                    borderRadius: BorderRadius.circular(10),
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
                          color: estaConectado ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        estaConectado ? 'En línea' : 'Desconectado',
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
                if (perfil.edad != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColores.suave,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${perfil.edad} años',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColores.oscuro,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 1),
              ],
            ),

            // Avatar del contacto
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColores.suave,
              backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                  ? MemoryImage(base64Decode(avatarBase64))
                  : ((avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl) as ImageProvider
                        : null),
              onBackgroundImageError:
                  (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? (exception, stackTrace) {
                      debugPrint("Aviso Web/CORS en perfil: $exception");
                    }
                  : null,
              child:
                  ((avatarBase64 == null || avatarBase64.isEmpty) &&
                      (avatarUrl == null || avatarUrl.isEmpty))
                  ? const Icon(
                      Icons.person_rounded,
                      size: 32,
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

            // Email
            if (perfil.email != null)
              Text(
                perfil.email!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColores.textoSecundario,
                ),
              ),

            // Botón de acción: Chatear
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final String destino = perfil.uid.isNotEmpty
                      ? perfil.uid
                      : (perfil.email ?? '');
                  Navigator.pushNamed(context, '/chat', arguments: destino);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  backgroundColor: AppColores.oscuro,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                label: const Text('Chatear', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta para usuarios en «Descubrir cercanos (< 25 km)»
  Widget _buildCardDescubrir(PerfilDistanciaDTO dto) {
    final perfil = dto.perfil;
    final bool estaConectado = perfil.conectado;

    final String nombre = (perfil.name != null && perfil.name!.isNotEmpty)
        ? perfil.name!
        : (perfil.email ?? 'Usuario cercano');
    final String? avatarUrl = perfil.urlAvatar;
    final String? avatarBase64 = perfil.avatarBase64;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColores.divisor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Fila superior: Badge de distancia destacada (izquierda) y estado (derecha)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColores.suave,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColores.principal.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 11,
                        color: AppColores.principal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dto.distanciaFormateada,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColores.oscuro,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: estaConectado ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),

            // Avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColores.suave,
              backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                  ? MemoryImage(base64Decode(avatarBase64))
                  : ((avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl) as ImageProvider
                        : null),
              onBackgroundImageError:
                  (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? (exception, stackTrace) {
                      debugPrint("Aviso Web/CORS en perfil: $exception");
                    }
                  : null,
              child:
                  ((avatarBase64 == null || avatarBase64.isEmpty) &&
                      (avatarUrl == null || avatarUrl.isEmpty))
                  ? const Icon(
                      Icons.person_outline_rounded,
                      size: 32,
                      color: AppColores.oscuro,
                    )
                  : null,
            ),

            // Nombre
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

            // Edad
            if (perfil.edad != null)
              Text(
                '${perfil.edad} años',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColores.textoSecundario,
                ),
              )
            else if (perfil.email != null)
              Text(
                perfil.email!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColores.textoSecundario,
                ),
              ),

            // Botón de acción: Chatear (al iniciar chat pasará a Mis Contactos y al Mapa)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final String destino = perfil.uid.isNotEmpty
                      ? perfil.uid
                      : (perfil.email ?? '');
                  Navigator.pushNamed(context, '/chat', arguments: destino);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  backgroundColor: AppColores.oscuro,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                label: const Text('Chatear', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DataHolder.instance.iBotBarIndex = 1;
    final miPos = DataHolder.instance.perfilUsuario.posicion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar',
            onPressed: () {
              _cargarContactosConChat();
              _cambiarFiltro(_filtroActivo);
            },
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Mi Perfil',
            onPressed: _mostrarModalEdicionPerfil,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'sembrar') {
                _sembrarDatosPrueba();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sembrar',
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 18,
                      color: AppColores.oscuro,
                    ),
                    SizedBox(width: 8),
                    Text('Sembrar 20 perfiles', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBarraFiltros(),
            Expanded(
              child: _cargandoFiltro
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColores.principal,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Cargando miembros...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorFiltro != null
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
                              _errorFiltro!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColores.texto,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _cambiarFiltro(_filtroActivo),
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
                  : _filtroActivo == 0
                  // ========================================================
                  // PESTAÑA 0: MIS CONTACTOS (CHATS ACTIVOS)
                  // ========================================================
                  ? _perfilesContactos.isEmpty
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
                                    'Explora «Descubrir (< 25 km)» para conocer miembros cercanos e iniciar una conversación.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColores.textoSecundario,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                    onPressed: () => _cambiarFiltro(1),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColores.oscuro,
                                    ),
                                    icon: const Icon(Icons.near_me_outlined),
                                    label: const Text('Descubrir cercanos'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _cargarContactosConChat();
                              await _cambiarFiltro(0);
                            },
                            child: GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.70,
                                  ),
                              itemCount: _perfilesContactos.length,
                              itemBuilder: (context, index) =>
                                  _buildCardContacto(_perfilesContactos[index]),
                            ),
                          )
                  // ========================================================
                  // PESTAÑA 1: DESCUBRIR CERCANOS (<= 25 KM SIN CHAT)
                  // ========================================================
                  : miPos == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppEspacios.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_off_outlined,
                              size: 56,
                              color: AppColores.divisor,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ubicación requerida',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColores.oscuro,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Para descubrir usuarios cercanos en un radio de 25 km, necesitamos conocer tu ubicación actual.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColores.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _obteniendoUbicacion
                                  ? null
                                  : _obtenerUbicacionYRecargar,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColores.oscuro,
                              ),
                              icon: _obteniendoUbicacion
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_rounded),
                              label: Text(
                                _obteniendoUbicacion
                                    ? 'Obteniendo GPS...'
                                    : 'Obtener mi ubicación actual',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _perfilesDescubrir.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppEspacios.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.radar_rounded,
                              size: 56,
                              color: AppColores.divisor,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No hay nuevos usuarios a menos de 25 km',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColores.oscuro,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Los usuarios con los que ya tienes conversación activa se muestran en «Mis Contactos» y en el Mapa.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColores.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _sembrarDatosPrueba,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColores.oscuro,
                                side: const BorderSide(
                                  color: AppColores.oscuro,
                                ),
                              ),
                              icon: const Icon(Icons.science_outlined),
                              label: const Text(
                                'Sembrar perfiles de prueba en la zona',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _cargarDescubrirCercanos();
                      },
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.70,
                            ),
                        itemCount: _perfilesDescubrir.length,
                        itemBuilder: (context, index) =>
                            _buildCardDescubrir(_perfilesDescubrir[index]),
                      ),
                    ),
            ),
          ],
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
