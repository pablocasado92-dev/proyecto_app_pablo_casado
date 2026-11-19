import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/data_holder.dart';
import '../fb_objects/partida.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// DIRECTORIO DE ENCUENTROS Y MESAS DE JUEGO MTG (EditProfileView)
/// ============================================================================
/// Cumple con la rúbrica de Consultas Firestore (0486 AD RA4.e / RA4.g):
/// 1. Filtro "Commander Abiertas": doble condición where con índice compuesto (estado, formato).
/// 2. Filtro "Próximas (Top 5)": orderBy('fechaHora') con limit(5).
/// 3. Filtro "Esta Semana": rango de fechas sobre Timestamp (>= hoy && <= hoy + 7 días).
/// 4. Filtro "Catálogo Paginado": paginación de lotes con startAfterDocument.
/// 5. Filtro "Cerca de mí": cálculo geodésico Haversine en Isolate secundario
///    con streaming bidireccional en tiempo real (Isolate.spawn, SendPort/ReceivePort).
/// 6. Filtro "Mis Contactos": lista de jugadores con chats activos.
///
/// Además permite unirse o desapuntarse de mesas, chatear con el organizador,
/// crear nuevas mesas de juego y editar el propio perfil del usuario.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  // ============================================================================
  // ESTADO DE FILTROS:
  // 0: Próximas (Top 5) -> orderBy + limit(5)
  // 1: Commander Abiertas -> where doble condición + índice compuesto
  // 2: Esta Semana -> Rango Timestamp
  // 3: Cerca de mí -> Isolate secundario con SendPort/ReceivePort en vivo
  // 4: Catálogo Paginado -> startAfterDocument en lotes
  // 5: Mis Contactos -> Jugadores con chat activo
  // ============================================================================
  int _filtroActivo = 0;

  bool _cargando = true;
  String? _errorMensaje;

  // Listas de datos según el filtro activo
  List<Partida> _partidas = [];
  List<PartidaDistanciaDTO> _partidasCercanas = [];
  List<Perfil> _perfilesContactos = [];

  // Paginación
  DocumentSnapshot? _ultimoDocPaginacion;
  bool _hayMasPaginadas = false;
  bool _cargandoMasPaginadas = false;

  // Estado del Isolate de ordenación por distancia
  bool _calculandoIsolate = false;
  double _progresoIsolate = 0.0;
  String _estadoIsolate = '';

  void _onMensajesActualizados(int _) {
    if (_filtroActivo == 5) {
      _cargarContactosConChat();
    }
  }

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 1;
    DataHolder.instance.perfilUsuario.addListener(_onMensajesActualizados);
    _aplicarFiltro(0);
  }

  @override
  void dispose() {
    DataHolder.instance.perfilUsuario.removeListener(_onMensajesActualizados);
    super.dispose();
  }

  // ============================================================================
  // EJECUCIÓN DE CONSULTAS FIRESTORE Y PROCESAMIENTO ISOLATE
  // ============================================================================

  Future<void> _aplicarFiltro(int indiceFiltro) async {
    if (!mounted) return;

    setState(() {
      _filtroActivo = indiceFiltro;
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      switch (indiceFiltro) {
        case 0:
          // CONSULTA 2 FIRESTORE: orderBy("fechaHora") + limit(5)
          final resultado = await DataHolder.instance.queriesAdmin
              .consultarProximasPartidas(limite: 5);
          if (!mounted) return;
          setState(() {
            _partidas = resultado;
            _cargando = false;
          });
          break;

        case 1:
          // CONSULTA 1 FIRESTORE: doble where (estado == 'abierta' && formato == 'Commander') con índice compuesto
          final resultado = await DataHolder.instance.queriesAdmin
              .consultarPartidasPorEstadoYFormato(
                estado: 'abierta',
                formato: 'Commander',
              );
          if (!mounted) return;
          setState(() {
            _partidas = resultado;
            _cargando = false;
          });
          break;

        case 2:
          // CONSULTA 3 FIRESTORE: Rango sobre Timestamp (próximos 7 días)
          final ahora = DateTime.now();
          final finSemana = ahora.add(const Duration(days: 7));
          final resultado = await DataHolder.instance.queriesAdmin
              .consultarPartidasPorRangoFechas(inicio: ahora, fin: finSemana);
          if (!mounted) return;
          setState(() {
            _partidas = resultado;
            _cargando = false;
          });
          break;

        case 3:
          // CONSULTA GEOGRÁFICA + ISOLATE SECUNDARIO CON STREAMING BIDIRECCIONAL (PSP RA2.c / RA2.e)
          await _ejecutarOrdenacionPartidasCercanas();
          break;

        case 4:
          // CONSULTA 4 FIRESTORE: Paginación determinista con startAfterDocument
          _ultimoDocPaginacion = null;
          final pag = await DataHolder.instance.queriesAdmin
              .consultarPartidasPaginadas(limite: 4, ultimoDocumento: null);
          if (!mounted) return;
          setState(() {
            _partidas = pag.partidas;
            _ultimoDocPaginacion = pag.ultimoDocumento;
            _hayMasPaginadas = pag.hayMas;
            _cargando = false;
          });
          break;

        case 5:
          // CONTACTOS DIRECTOS CON CHAT ACTIVO
          await _cargarContactosConChat();
          if (!mounted) return;
          setState(() {
            _cargando = false;
          });
          break;
      }
    } catch (e) {
      debugPrint("Error aplicando filtro $indiceFiltro: $e");
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorMensaje = 'No se pudieron cargar los datos: $e';
      });
    }
  }

  /// Carga la siguiente página de partidas paginadas con startAfterDocument
  Future<void> _cargarMasPartidasPaginadas() async {
    if (_cargandoMasPaginadas || !_hayMasPaginadas) return;

    setState(() {
      _cargandoMasPaginadas = true;
    });

    try {
      final pag = await DataHolder.instance.queriesAdmin
          .consultarPartidasPaginadas(
            limite: 4,
            ultimoDocumento: _ultimoDocPaginacion,
          );

      if (!mounted) return;
      setState(() {
        _partidas.addAll(pag.partidas);
        _ultimoDocPaginacion = pag.ultimoDocumento;
        _hayMasPaginadas = pag.hayMas;
        _cargandoMasPaginadas = false;
      });
    } catch (e) {
      debugPrint("Error cargando más partidas: $e");
      if (!mounted) return;
      setState(() {
        _cargandoMasPaginadas = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al paginar partidas: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Descarga todas las mesas y ordena por distancia en un Isolate secundario (Isolate.spawn)
  /// recibiendo progreso continuo por ReceivePort y actualizando LinearProgressIndicator.
  Future<void> _ejecutarOrdenacionPartidasCercanas() async {
    final miPos = DataHolder.instance.perfilUsuario.posicion;

    if (miPos == null) {
      if (!mounted) return;
      setState(() {
        _partidasCercanas = [];
        _cargando = false;
      });
      return;
    }

    setState(() {
      _calculandoIsolate = true;
      _progresoIsolate = 0.05;
      _estadoIsolate = 'Consultando mesas en Firestore...';
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("Partidas")
          .withConverter<Partida>(
            fromFirestore: Partida.fromFirestore,
            toFirestore: (Partida p, _) => p.toFirestore(),
          )
          .get();

      final todas = snapshot.docs.map((d) => d.data()).toList();

      if (todas.isEmpty) {
        if (!mounted) return;
        setState(() {
          _partidasCercanas = [];
          _calculandoIsolate = false;
          _cargando = false;
          _estadoIsolate = '';
        });
        return;
      }

      // Iniciar el cálculo en Isolate secundario con streaming de progreso bidireccional
      final ordenadas = await DataHolder.instance.locationAdmin
          .ordenarPartidasPorCercaniaEnIsolate(
            partidas: todas,
            origenLat: miPos.latitude,
            origenLng: miPos.longitude,
            onProgreso: (porcentaje, mensaje) {
              if (mounted) {
                setState(() {
                  _progresoIsolate = porcentaje;
                  _estadoIsolate = mensaje;
                });
              }
            },
          );

      if (!mounted) return;
      setState(() {
        _partidasCercanas = ordenadas;
        _calculandoIsolate = false;
        _cargando = false;
        _estadoIsolate = '';
      });
    } catch (e) {
      debugPrint("Error en isolate de partidas cercanas: $e");
      if (!mounted) return;
      setState(() {
        _calculandoIsolate = false;
        _cargando = false;
        _errorMensaje = 'Error al calcular distancias en Isolate: $e';
      });
    }
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

  // ============================================================================
  // ACCIONES SOBRE MESAS DE JUEGO (UNIRSE, ABANDONAR, ELIMINAR, CREAR)
  // ============================================================================

  Future<void> _unirseAPartida(Partida partida) async {
    final miUid =
        FirebaseAuth.instance.currentUser?.uid ??
        DataHolder.instance.perfilUsuario.uid;
    if (miUid.isEmpty) return;

    try {
      final exito = await DataHolder.instance.queriesAdmin.unirseAPartida(
        partidaId: partida.id,
        userUid: miUid,
      );

      if (!mounted) return;
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Te has unido a la mesa "${partida.titulo}"!'),
            backgroundColor: Colors.green,
          ),
        );
        _aplicarFiltro(_filtroActivo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No fue posible unirte (mesa completa o inexistente).',
            ),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al unirse: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _abandonarPartida(Partida partida) async {
    final miUid =
        FirebaseAuth.instance.currentUser?.uid ??
        DataHolder.instance.perfilUsuario.uid;
    if (miUid.isEmpty) return;

    try {
      await DataHolder.instance.queriesAdmin.abandonarPartida(
        partidaId: partida.id,
        userUid: miUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Has salido de la mesa "${partida.titulo}".'),
          backgroundColor: Colors.blueGrey,
        ),
      );
      _aplicarFiltro(_filtroActivo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abandonar mesa: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _confirmarEliminarPartida(Partida partida) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Mesa'),
        content: Text(
          '¿Estás seguro de que deseas cancelar y eliminar la mesa "${partida.titulo}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await DataHolder.instance.queriesAdmin.eliminarPartida(partida.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesa eliminada con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
      _aplicarFiltro(_filtroActivo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar mesa: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Despliega el modal interactivo para convocar una nueva mesa de juego MTG
  void _mostrarModalCrearPartida() {
    final formKey = GlobalKey<FormState>();
    final tituloCtrl = TextEditingController();
    final ubicacionCtrl = TextEditingController(
      text: 'Padis Comics & Games (Madrid)',
    );
    final descCtrl = TextEditingController();

    String formato = 'Commander';
    int maxJugadores = 4;
    DateTime fechaSeleccionada = DateTime.now().add(
      const Duration(days: 1, hours: 2),
    );
    bool esTorneo = false;
    bool guardando = false;

    final miPerfil = DataHolder.instance.perfilUsuario;
    GeoPoint puntoPosicion =
        miPerfil.posicion ?? const GeoPoint(40.4284, -3.7025);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColores.tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadios.cabecera),
        ),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppEspacios.md,
                right: AppEspacios.md,
                top: AppEspacios.md,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      const Row(
                        children: [
                          Icon(
                            Icons.add_location_alt_rounded,
                            color: AppColores.principal,
                            size: 26,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Convocar Mesa MTG',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColores.texto,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Título
                      TextFormField(
                        controller: tituloCtrl,
                        decoration: InputDecoration(
                          labelText: 'Título del encuentro',
                          hintText:
                              'Ej. Commander Casual 6-7, Draft Bloomburrow',
                          prefixIcon: const Icon(Icons.title_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa un título'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Formato y Tipo
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              dropdownColor: AppColores.tarjeta,
                              initialValue: formato,
                              decoration: InputDecoration(
                                labelText: 'Formato',
                                prefixIcon: const Icon(Icons.style_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadios.campo,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Commander',
                                  child: Text('Commander (EDH)'),
                                ),
                                DropdownMenuItem(
                                  value: 'Modern',
                                  child: Text('Modern'),
                                ),
                                DropdownMenuItem(
                                  value: 'Standard',
                                  child: Text('Standard'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pioneer',
                                  child: Text('Pioneer'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pauper',
                                  child: Text('Pauper'),
                                ),
                                DropdownMenuItem(
                                  value: 'Draft/Limited',
                                  child: Text('Draft / Limited'),
                                ),
                                DropdownMenuItem(
                                  value: 'Premodern',
                                  child: Text('Premodern'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    formato = val;
                                    if (formato == 'Commander') {
                                      maxJugadores = 4;
                                    } else if (formato == 'Draft/Limited') {
                                      maxJugadores = 8;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              dropdownColor: AppColores.tarjeta,
                              initialValue: maxJugadores,
                              decoration: InputDecoration(
                                labelText: 'Plazas',
                                prefixIcon: const Icon(Icons.group_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadios.campo,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('2 Jugadores (1v1)'),
                                ),
                                DropdownMenuItem(
                                  value: 4,
                                  child: Text('4 Jugadores (Pod)'),
                                ),
                                DropdownMenuItem(
                                  value: 6,
                                  child: Text('6 Jugadores'),
                                ),
                                DropdownMenuItem(
                                  value: 8,
                                  child: Text('8 Jugadores (Draft)'),
                                ),
                                DropdownMenuItem(
                                  value: 16,
                                  child: Text('16 Plazas (Torneo)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => maxJugadores = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Ubicación / Tienda
                      TextFormField(
                        controller: ubicacionCtrl,
                        decoration: InputDecoration(
                          labelText: 'Tienda, ludoteca o lugar',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa el lugar'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Selector de Fecha y Hora
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColores.suave,
                          borderRadius: BorderRadius.circular(AppRadios.campo),
                          border: Border.all(color: AppColores.divisor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColores.oscuro,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fecha y hora de inicio',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColores.textoSecundario,
                                    ),
                                  ),
                                  Text(
                                    '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')} a las ${fechaSeleccionada.hour.toString().padLeft(2, '0')}:${fechaSeleccionada.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.texto,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: modalCtx,
                                  initialDate: fechaSeleccionada,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 90),
                                  ),
                                );
                                if (d == null) return;
                                if (!modalCtx.mounted) return;
                                final t = await showTimePicker(
                                  context: modalCtx,
                                  initialTime: TimeOfDay.fromDateTime(
                                    fechaSeleccionada,
                                  ),
                                );
                                if (t == null) return;
                                setModalState(() {
                                  fechaSeleccionada = DateTime(
                                    d.year,
                                    d.month,
                                    d.day,
                                    t.hour,
                                    t.minute,
                                  );
                                });
                              },
                              child: const Text('Modificar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Descripción / Requisitos
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText:
                              'Detalles (nivel, proxys permitidas, premios...)',
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Es Torneo switch
                      SwitchListTile(
                        value: esTorneo,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Es Torneo oficial / con premios'),
                        onChanged: (val) {
                          setModalState(() => esTorneo = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Botón Publicar Mesa
                      FilledButton.icon(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => guardando = true);

                                try {
                                  final miUid =
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      miPerfil.uid;
                                  final miNombre =
                                      miPerfil.name ??
                                      (FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.displayName ??
                                          'Organizador');

                                  final nueva = Partida(
                                    id: '',
                                    titulo: tituloCtrl.text.trim(),
                                    formato: formato,
                                    fechaHora: Timestamp.fromDate(
                                      fechaSeleccionada,
                                    ),
                                    creadorUID: miUid,
                                    creadorNombre: miNombre,
                                    ubicacionNombre: ubicacionCtrl.text.trim(),
                                    posicion: puntoPosicion,
                                    jugadoresUIDs: [
                                      miUid,
                                    ], // El creador se une automáticamente
                                    maxJugadores: maxJugadores,
                                    estado: 'abierta',
                                    descripcion: descCtrl.text.trim().isNotEmpty
                                        ? descCtrl.text.trim()
                                        : null,
                                    esTorneo: esTorneo,
                                  );

                                  await DataHolder.instance.queriesAdmin
                                      .guardarPartida(nueva);

                                  if (modalCtx.mounted) {
                                    Navigator.pop(modalCtx);
                                  }

                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '¡Mesa MTG convocada y publicada!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _aplicarFiltro(_filtroActivo);
                                } catch (e) {
                                  setModalState(() => guardando = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al crear mesa: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColores.oscuro,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        icon: guardando
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
                          guardando ? 'Publicando...' : 'Publicar Mesa MTG',
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

  // ============================================================================
  // GESTIÓN DE PERFIL PROPIO (EDICIÓN Y BORRADO DE CUENTA)
  // ============================================================================

  void _mostrarModalEdicionPerfil() {
    final perfilActual = DataHolder.instance.perfilUsuario;
    final String uid =
        FirebaseAuth.instance.currentUser?.uid ?? perfilActual.uid;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: perfilActual.name ?? '');
    final bioController = TextEditingController(
      text: perfilActual.biografiaMTG ?? '',
    );
    String? selectedNivel = perfilActual.nivelJuego ?? 'Casual';
    List<String> selectedFormatos = List<String>.from(
      perfilActual.formatosPreferidos,
    );
    const List<String> formatosDisponibles = [
      'Commander',
      'Modern',
      'Standard',
      'Pioneer',
      'Pauper',
      'Premodern',
      'Draft/Limited',
    ];
    String currentAvatarUrl = perfilActual.urlAvatar ?? '';
    String? currentAvatarBase64 = perfilActual.avatarBase64;
    XFile? nuevaImagenSeleccionada;
    Uint8List? previewBytes;
    String estadoIsolate = '';
    bool isProcessingIsolate = false;
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
      backgroundColor: AppColores.tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadios.cabecera),
        ),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> seleccionarImagen(ImageSource source) async {
              Navigator.pop(ctx);
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

                  // PSP RA2.c / RA2.e: Compresión asíncrona en ISOLATE con BackgroundIsolateBinaryMessenger
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
                      'No se pudo acceder a la ${source == ImageSource.camera ? "cámara" : "galería"}.',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }

            void mostrarOpcionesOrigen() {
              showModalBottomSheet(
                context: modalContext,
                backgroundColor: AppColores.tarjeta,
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
                              color: AppColores.texto,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            leading: const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColores.oscuro,
                            ),
                            title: const Text(
                              'Tomar foto con la cámara',
                              style: TextStyle(color: AppColores.texto),
                            ),
                            onTap: () => seleccionarImagen(ImageSource.camera),
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.photo_library_rounded,
                              color: AppColores.oscuro,
                            ),
                            title: const Text(
                              'Elegir de la galería',
                              style: TextStyle(color: AppColores.texto),
                            ),
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
                              color: AppColores.texto,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Avatar preview
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

                      // Nombre
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
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa tu nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Edad
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        dropdownColor: AppColores.tarjeta,
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
                          final e = 16 + i;
                          return DropdownMenuItem<int>(
                            value: e,
                            child: Text('$e años'),
                          );
                        }),
                        onChanged: (val) =>
                            setModalState(() => selectedEdad = val),
                      ),
                      const SizedBox(height: 12),

                      // Nivel de juego
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        dropdownColor: AppColores.tarjeta,
                        initialValue: selectedNivel,
                        decoration: InputDecoration(
                          labelText: 'Nivel / Estilo de Juego',
                          prefixIcon: const Icon(Icons.military_tech_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Casual',
                            child: Text(
                              'Casual (Mesa distendida / Cocina)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Competitivo',
                            child: Text(
                              'Competitivo (Torneos / Tier 1)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Iniciación',
                            child: Text(
                              'Iniciación (Aprendiendo mecánicas)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setModalState(() => selectedNivel = val),
                      ),
                      const SizedBox(height: 12),

                      // Formatos preferidos
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColores.suave,
                          borderRadius: BorderRadius.circular(AppRadios.campo),
                          border: Border.all(color: AppColores.divisor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.style_outlined,
                                  size: 18,
                                  color: AppColores.oscuro,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Formatos favoritos de MTG',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.texto,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: formatosDisponibles.map((f) {
                                final isSelected = selectedFormatos.contains(f);
                                return FilterChip(
                                  label: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColores.texto,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColores.oscuro,
                                  checkmarkColor: Colors.white,
                                  backgroundColor: AppColores.fondo,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColores.oscuro
                                        : AppColores.divisor,
                                  ),
                                  onSelected: (bool selected) {
                                    setModalState(() {
                                      if (selected) {
                                        selectedFormatos.add(f);
                                      } else {
                                        selectedFormatos.remove(f);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Biografía
                      TextFormField(
                        controller: bioController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Biografía MTG / Comandantes',
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.auto_stories_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadios.campo,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Geolocalización GPS
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColores.suave,
                          borderRadius: BorderRadius.circular(AppRadios.campo),
                          border: Border.all(color: AppColores.divisor),
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
                                      color: AppColores.texto,
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
                                  'Lat: ${currentPosicion!.latitude.toStringAsFixed(4)}, '
                                  'Lng: ${currentPosicion!.longitude.toStringAsFixed(4)}',
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
                                  'Sin ubicación registrada. Pulsa para capturar coordenadas GPS.',
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
                                      setModalState(() => isLocating = true);

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
                                                  'GPS obtenido con éxito.',
                                                ),
                                                backgroundColor: Colors.green,
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
                                setModalState(() => isSavingModal = true);

                                final nuevoNombre = nameController.text.trim();

                                try {
                                  if (uid.isNotEmpty) {
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
                                    perfilMemoria.conectado = true;
                                    perfilMemoria.biografiaMTG = bioController
                                        .text
                                        .trim();
                                    perfilMemoria.nivelJuego = selectedNivel;
                                    perfilMemoria.formatosPreferidos =
                                        selectedFormatos;

                                    // Modificar documento propio con update()
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
                                  _aplicarFiltro(_filtroActivo);

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
                                  setModalState(() => isSavingModal = false);
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

  void _confirmarEliminarPerfil(String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar perfil'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar permanentemente tu perfil? '
          'Se borrarán tus datos en Cloud Firestore y se cerrará tu sesión.',
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
                await FirebaseFirestore.instance
                    .collection("Perfiles")
                    .doc(uid)
                    .delete();
                await DataHolder.instance.detenerPresencia();
                DataHolder.instance.clearData();
                await FirebaseAuth.instance.signOut();

                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar perfil: $e'),
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

  Future<void> _sembrarMesasPrueba() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sembrando 20 mesas y torneos MTG en Firestore...'),
          duration: Duration(seconds: 2),
        ),
      );
      final count = await DataHolder.instance.queriesAdmin
          .sembrarPartidasPrueba();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡$count mesas MTG listas en Firestore!'),
          backgroundColor: Colors.green,
        ),
      );
      _aplicarFiltro(_filtroActivo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sembrar mesas: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================================
  // WIDGETS DE LA INTERFAZ
  // ============================================================================

  Widget _buildBarraFiltros() {
    final List<({int id, String titulo, IconData icono})> filtros = [
      (id: 0, titulo: 'Próximas (Top 5)', icono: Icons.schedule_rounded),
      (id: 1, titulo: 'Commander Abiertas', icono: Icons.groups_rounded),
      (id: 2, titulo: 'Esta Semana', icono: Icons.date_range_rounded),
      (id: 3, titulo: 'Cerca de mí', icono: Icons.near_me_rounded),
      (id: 4, titulo: 'Catálogo Paginado', icono: Icons.auto_stories_rounded),
      (
        id: 5,
        titulo: 'Mis Contactos (${_perfilesContactos.length})',
        icono: Icons.chat_bubble_outline_rounded,
      ),
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: filtros.map((f) {
            final bool seleccionado = _filtroActivo == f.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: seleccionado,
                showCheckmark: false,
                avatar: Icon(
                  f.icono,
                  size: 15,
                  color: seleccionado ? Colors.white : AppColores.oscuro,
                ),
                label: Text(
                  f.titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: seleccionado
                        ? FontWeight.bold
                        : FontWeight.w500,
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
                onSelected: (_) => _aplicarFiltro(f.id),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Tarjeta visual para una Mesa o Torneo MTG (Partida)
  Widget _buildCardPartida(Partida partida, {double? distanciaKm}) {
    final miUid =
        FirebaseAuth.instance.currentUser?.uid ??
        DataHolder.instance.perfilUsuario.uid;
    final bool yoSoyCreador = partida.creadorUID == miUid;
    final bool yoEstoyApuntado = partida.jugadoresUIDs.contains(miUid);

    final fechaDT = partida.fechaHora.toDate();
    final fechaStr =
        '${fechaDT.day.toString().padLeft(2, '0')}/${fechaDT.month.toString().padLeft(2, '0')} · ${fechaDT.hour.toString().padLeft(2, '0')}:${fechaDT.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: yoEstoyApuntado ? AppColores.principal : AppColores.divisor,
          width: yoEstoyApuntado ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Formato, Distancia, y Estado de Plazas
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColores.oscuro,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    partida.formato,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (partida.esTorneo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade300),
                    ),
                    child: Text(
                      'TORNEO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ),
                const Spacer(),
                if (distanciaKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
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
                          distanciaKm < 1.0
                              ? '${(distanciaKm * 1000).round()} m'
                              : '${distanciaKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColores.oscuro,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Título de la mesa
            Text(
              partida.titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColores.texto,
              ),
            ),
            const SizedBox(height: 6),

            // Lugar / Tienda
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: AppColores.oscuro,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    partida.ubicacionNombre,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColores.texto,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Fecha y hora
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: AppColores.oscuro,
                ),
                const SizedBox(width: 6),
                Text(
                  fechaStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Plazas
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: partida.estaLlena
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: partida.estaLlena
                          ? Colors.red.shade300
                          : Colors.green.shade400,
                    ),
                  ),
                  child: Text(
                    '${partida.jugadoresUIDs.length}/${partida.maxJugadores} jugadores',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: partida.estaLlena
                          ? Colors.red.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),

            if (partida.descripcion != null &&
                partida.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                partida.descripcion!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColores.textoSecundario,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColores.divisor),
            const SizedBox(height: 10),

            // Fila de acciones: Unirme / Salir / Chatear / Borrar
            Row(
              children: [
                // Botón principal: Unirme / Salir
                if (yoEstoyApuntado)
                  OutlinedButton.icon(
                    onPressed: () => _abandonarPartida(partida),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade400),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Apuntado (Salir)'),
                  )
                else if (partida.estaLlena)
                  FilledButton.tonal(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('Mesa Llena'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _unirseAPartida(partida),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColores.oscuro,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(Icons.group_add_rounded, size: 16),
                    label: const Text('Unirme'),
                  ),

                const SizedBox(width: 8),

                // Botón: Chatear con el Organizador
                IconButton.outlined(
                  onPressed: () {
                    final String destino = partida.creadorUID;
                    if (destino.isNotEmpty) {
                      Navigator.pushNamed(context, '/chat', arguments: destino);
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  tooltip: 'Chatear con organizador (${partida.creadorNombre})',
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: AppColores.divisor),
                  ),
                ),

                const Spacer(),

                // Si soy el creador, botón para eliminar
                if (yoSoyCreador)
                  IconButton(
                    onPressed: () => _confirmarEliminarPartida(partida),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Cancelar y eliminar mesa',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de contacto con chat activo
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
                  Text(
                    '${perfil.edad} años',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColores.oscuro,
                    ),
                  ),
              ],
            ),
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColores.suave,
              backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                  ? MemoryImage(base64Decode(avatarBase64))
                  : ((avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl) as ImageProvider
                        : null),
              child:
                  ((avatarBase64 == null || avatarBase64.isEmpty) &&
                      (avatarUrl == null || avatarUrl.isEmpty))
                  ? const Icon(
                      Icons.person_rounded,
                      size: 30,
                      color: AppColores.oscuro,
                    )
                  : null,
            ),
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
        title: const Text('Mesas MTG'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () => _aplicarFiltro(_filtroActivo),
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
              if (value == 'sembrar_partidas') {
                _sembrarMesasPrueba();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sembrar_partidas',
                child: Row(
                  children: [
                    Icon(
                      Icons.table_restaurant_rounded,
                      size: 18,
                      color: AppColores.oscuro,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Sembrar 20 mesas MTG',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarModalCrearPartida,
        backgroundColor: AppColores.oscuro,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear Mesa'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBarraFiltros(),

            // Indicador de streaming en vivo del Isolate secundario (PSP RA2.c / RA2.e)
            if (_calculandoIsolate || _estadoIsolate.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppColores.suave,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColores.principal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _estadoIsolate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.oscuro,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${(_progresoIsolate * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColores.principal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _progresoIsolate > 0 ? _progresoIsolate : null,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColores.principal,
                      ),
                    ),
                  ],
                ),
              ),

            // Contenedor principal de resultados
            Expanded(
              child: _cargando
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColores.principal,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Consultando mesas MTG en Firestore...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMensaje != null
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
                              _errorMensaje!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColores.texto,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _aplicarFiltro(_filtroActivo),
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
                  // ========================================================
                  // FILTRO 5: MIS CONTACTOS (CHATS ACTIVOS)
                  // ========================================================
                  : _filtroActivo == 5
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
                                    'Aún no tienes contactos con chat',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.oscuro,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Entra en cualquier mesa de juego y pulsa el botón de chatear para coordinar con el organizador.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColores.textoSecundario,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
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
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: _perfilesContactos.length,
                            itemBuilder: (context, index) =>
                                _buildCardContacto(_perfilesContactos[index]),
                          )
                  // ========================================================
                  // FILTRO 3: CERCA DE MÍ (ORDENADO EN ISOLATE SECUNDARIO)
                  // ========================================================
                  : _filtroActivo == 3
                  ? miPos == null
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
                                    'Para calcular la distancia exacta con las mesas de juego, captura tu GPS en Mi Perfil.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColores.textoSecundario,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _mostrarModalEdicionPerfil,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColores.oscuro,
                                    ),
                                    icon: const Icon(Icons.my_location_rounded),
                                    label: const Text('Capturar mi GPS'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _partidasCercanas.isEmpty
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
                                    'No hay mesas registradas con GPS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColores.oscuro,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _sembrarMesasPrueba,
                                    icon: const Icon(Icons.science_outlined),
                                    label: const Text(
                                      'Sembrar 20 mesas MTG de prueba',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80, top: 8),
                            itemCount: _partidasCercanas.length,
                            itemBuilder: (context, index) {
                              final dto = _partidasCercanas[index];
                              return _buildCardPartida(
                                dto.partida,
                                distanciaKm: dto.distanciaKm,
                              );
                            },
                          )
                  // ========================================================
                  // FILTROS 0, 1, 2, 4: LISTA DE PARTIDAS FIRESTORE
                  // ========================================================
                  : _partidas.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppEspacios.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.table_restaurant_outlined,
                              size: 56,
                              color: AppColores.divisor,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron mesas para este filtro',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColores.oscuro,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pulsa "Crear Mesa" para inaugurar un encuentro o siembra mesas de prueba.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColores.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _sembrarMesasPrueba,
                              icon: const Icon(Icons.science_outlined),
                              label: const Text('Sembrar 20 mesas MTG'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80, top: 8),
                      itemCount:
                          _partidas.length +
                          (_filtroActivo == 4 && _hayMasPaginadas ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _partidas.length) {
                          // Botón para cargar más lotes paginados con startAfterDocument
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: _cargandoMasPaginadas
                                  ? const CircularProgressIndicator(
                                      color: AppColores.principal,
                                    )
                                  : FilledButton.tonalIcon(
                                      onPressed: _cargarMasPartidasPaginadas,
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                      ),
                                      label: const Text(
                                        'Cargar más mesas (Paginación)',
                                      ),
                                    ),
                            ),
                          );
                        }
                        return _buildCardPartida(_partidas[index]);
                      },
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
