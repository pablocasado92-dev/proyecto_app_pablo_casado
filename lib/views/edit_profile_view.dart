import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  // Estados de la colección (Carga, Vacío y Error)
  bool _isLoading = true;
  String? _errorMessage;

  void _onMensajesActualizados(int _) {
    if (mounted) {
      _cargarPerfilesDesdeFirestore();
    }
  }

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 1;
    DataHolder.instance.perfilUsuario.addListener(_onMensajesActualizados);
    DataHolder.instance.perfilUsuario.descargarMensajes();
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
    final avatarUrlController = TextEditingController(
      text: perfilActual.urlAvatar ?? '',
    );
    int? selectedEdad = perfilActual.edad;
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

                      // Vista previa dinámica del Avatar
                      Center(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: avatarUrlController,
                          builder: (context, val, _) {
                            final String url = val.text.trim();
                            return CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColores.principal,
                              backgroundImage: url.isNotEmpty
                                  ? NetworkImage(url)
                                  : null,
                              child: url.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.white,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

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
                        items: List.generate(100, (i) {
                          final e = i + 1;
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

                      // Campo: URL Foto Avatar
                      TextFormField(
                        controller: avatarUrlController,
                        decoration: InputDecoration(
                          labelText: 'URL Foto de Avatar',
                          hintText: 'https://ejemplo.com/avatar.png',
                          prefixIcon: const Icon(Icons.link_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
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
                                final nuevaUrl = avatarUrlController.text
                                    .trim();

                                try {
                                  if (uid.isNotEmpty) {
                                    final perfilMemoria =
                                        DataHolder.instance.perfilUsuario;
                                    perfilMemoria.name = nuevoNombre;
                                    perfilMemoria.edad = selectedEdad;
                                    perfilMemoria.urlAvatar = nuevaUrl;
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
                                  setModalState(() {
                                    isSavingModal = false;
                                  });
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al guardar: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        icon: isSavingModal
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('Guardar Cambios'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColores.oscuro,
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
        title: const Text('Perfiles en Conversación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar perfiles',
            onPressed: _cargarPerfilesDesdeFirestore,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Editar mi perfil',
            onPressed: _mostrarModalEdicionPerfil,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            // 1. ESTADO DE CARGA
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColores.oscuro),
                    SizedBox(height: 14),
                    Text(
                      'Cargando perfiles con conversaciones activas...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColores.textoSecundario,
                      ),
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
                        style: const TextStyle(
                          color: AppColores.texto,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _cargarPerfilesDesdeFirestore,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : _perfiles.isEmpty
            // 3. ESTADO VACÍO
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 64,
                        color: AppColores.textoSecundario,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Sin conversaciones iniciadas',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColores.oscuro,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Solo se muestran los perfiles de personas con las que has intercambiado mensajes.\nInicia una conversación para ver sus perfiles aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.popAndPushNamed(context, '/conversaciones');
                        },
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('Ir a Mensajes'),
                      ),
                    ],
                  ),
                ),
              )
            // 4. CONTENIDO PRINCIPAL: PERFILES EN CONVERSACIÓN (GridView.builder)
            : RefreshIndicator(
                onRefresh: _cargarPerfilesDesdeFirestore,
                color: AppColores.oscuro,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera resumen de la sección en cuadrícula
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PERFILES EN CONVERSACIÓN',
                                  style: AppTextos.seccion,
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColores.texto,
                                      ),
                                    ),

                                    // Información de edad o email
                                    if (perfil.edad != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColores.suave,
                                          borderRadius: BorderRadius.circular(
                                            12,
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
