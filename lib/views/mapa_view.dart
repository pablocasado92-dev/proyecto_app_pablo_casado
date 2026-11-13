import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/data_holder.dart';
import '../ins_lib/bot_bars/ins_bot_bar_style1.dart';
import '../ins_lib/theme/app_theme.dart';

/// ============================================================================
/// PANTALLA DE MAPA Y CONTACTOS CERCANOS (MapaView) — FASE 1b (BLOQUE 6)
/// ============================================================================
/// Integra `flutter_map` con teselas de OpenStreetMap (0489 PMDM RA2.k) y
/// ordenación de perfiles por distancia en un ISOLATE secundario (0490 PSP RA2.c/e).
class MapaView extends StatefulWidget {
  const MapaView({super.key});

  @override
  State<MapaView> createState() => _MapaViewState();
}

class _MapaViewState extends State<MapaView> {
  final MapController _mapController = MapController();

  // 0: Vista de Mapa interactivo, 1: Lista «Cerca de mí»
  int _tabSeleccionada = 0;

  bool _cargandoPerfiles = true;
  bool _calculandoIsolate = false;
  String _estadoIsolate = '';

  List<Perfil> _todosLosPerfiles = [];
  List<PerfilDistanciaDTO> _perfilesCercanos = [];

  // Coordenadas por defecto (Madrid - Puerta del Sol) en caso de que el usuario no tenga GPS aún
  static const LatLng _coordMadrid = LatLng(40.4168, -3.7038);

  @override
  void initState() {
    super.initState();
    DataHolder.instance.iBotBarIndex = 2; // Pestaña 2 del BottomBar
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargandoPerfiles = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("Perfiles")
          .withConverter<Perfil>(
            fromFirestore: Perfil.fromFirestore,
            toFirestore: (Perfil p, _) => p.toFirestore(),
          )
          .get();

      final misDatos = DataHolder.instance.perfilUsuario;
      final String currentUid = misDatos.uid.trim().toLowerCase();
      final String currentEmail = (misDatos.email ?? '').trim().toLowerCase();

      // Recopilar contactos con conversaciones activas
      final Set<String> contactosConChat = {};
      for (final m in misDatos.mensajes) {
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

      // Filtrar perfiles: sólo aquellos con los que existe conversación activa y que no sea uno mismo
      final perfiles = snapshot.docs.map((d) => d.data()).where((p) {
        final pUid = p.uid.trim().toLowerCase();
        final pEmail = (p.email ?? '').trim().toLowerCase();

        // Descartar al propio usuario
        if (pUid == currentUid ||
            (currentEmail.isNotEmpty && pEmail == currentEmail)) {
          return false;
        }

        // Exigir que exista conversación previa
        return contactosConChat.contains(pUid) ||
            (pEmail.isNotEmpty && contactosConChat.contains(pEmail));
      }).toList();

      if (!mounted) return;

      setState(() {
        _todosLosPerfiles = perfiles;
        _cargandoPerfiles = false;
      });

      // Ejecutar el cálculo y ordenación en Isolate si tenemos la ubicación del usuario
      _ejecutarOrdenacionEnIsolate();
    } catch (e) {
      debugPrint("Error cargando perfiles para el mapa: $e");
      if (!mounted) return;
      setState(() {
        _cargandoPerfiles = false;
      });
    }
  }

  /// Obtiene la clave de contacto canónica utilizada en la conversación existente
  String _obtenerContactoConversacionExistente(Perfil perfil) {
    final conversaciones = DataHolder.instance.getConversaciones();
    final pUid = perfil.uid.trim().toLowerCase();
    final pEmail = (perfil.email ?? '').trim().toLowerCase();

    for (final c in conversaciones) {
      final key = c.contactoUidOrEmail.trim().toLowerCase();
      if ((pUid.isNotEmpty && key == pUid) ||
          (pEmail.isNotEmpty && key == pEmail)) {
        return c.contactoUidOrEmail; // Retorna la clave exacta de la conversación existente
      }
    }

    // Fallback si no coincidió exactamente
    return (perfil.email != null && perfil.email!.isNotEmpty)
        ? perfil.email!
        : perfil.uid;
  }

  /// Navega al hilo de chat existente con el contacto
  void _abrirConversacion(Perfil perfil) {
    final contactoKey = _obtenerContactoConversacionExistente(perfil);
    DataHolder.instance.contactoChatSeleccionado = contactoKey;
    Navigator.pushNamed(context, '/chat', arguments: contactoKey).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Ejecuta la ordenación geográfica mediante la fórmula de Haversine en un Isolate (PSP RA2.c / RA2.e)
  Future<void> _ejecutarOrdenacionEnIsolate() async {
    final miPosicion = DataHolder.instance.perfilUsuario.posicion;
    if (miPosicion == null || _todosLosPerfiles.isEmpty) return;

    setState(() {
      _calculandoIsolate = true;
      _estadoIsolate = 'Calculando distancias en Isolate secundario...';
    });

    try {
      final ordenados = await DataHolder.instance.locationAdmin
          .ordenarPerfilesPorCercaniaEnIsolate(
            perfiles: _todosLosPerfiles,
            origenLat: miPosicion.latitude,
            origenLng: miPosicion.longitude,
            onProgreso: (estado) {
              if (mounted) {
                setState(() {
                  _estadoIsolate = estado;
                });
              }
            },
          );

      if (!mounted) return;
      setState(() {
        _perfilesCercanos = ordenados;
        _calculandoIsolate = false;
        _estadoIsolate = '';
      });
    } catch (e) {
      debugPrint("Error en Isolate de ordenación de distancias: $e");
      if (!mounted) return;
      setState(() {
        _calculandoIsolate = false;
        _estadoIsolate = '';
      });
    }
  }

  /// Obtiene el centro del mapa (mi ubicación si existe, o Madrid por defecto)
  LatLng _obtenerCentroMapa() {
    final pos = DataHolder.instance.perfilUsuario.posicion;
    if (pos != null) {
      return LatLng(pos.latitude, pos.longitude);
    }
    return _coordMadrid;
  }

  /// Despliega el modal de detalle del contacto seleccionado en el mapa
  void _mostrarDetallePerfil(Perfil perfil) {
    final miPos = DataHolder.instance.perfilUsuario.posicion;
    String? distanciaStr;
    if (miPos != null && perfil.posicion != null) {
      final d = LocationAdmin.calcularDistanciaHaversine(
        miPos.latitude,
        miPos.longitude,
        perfil.posicion!.latitude,
        perfil.posicion!.longitude,
      );
      distanciaStr = d < 1.0
          ? '${(d * 1000).round()} m'
          : '${d.toStringAsFixed(1)} km';
    }

    final avatarUrl = perfil.urlAvatar;
    final avatarBase64 = perfil.avatarBase64;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadios.cabecera),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColores.suave,
                      backgroundImage:
                          (avatarBase64 != null && avatarBase64.isNotEmpty)
                          ? MemoryImage(base64Decode(avatarBase64))
                          : ((avatarUrl != null && avatarUrl.isNotEmpty)
                                ? NetworkImage(avatarUrl) as ImageProvider
                                : null),
                      child:
                          ((avatarBase64 == null || avatarBase64.isEmpty) &&
                              (avatarUrl == null || avatarUrl.isEmpty))
                          ? const Icon(
                              Icons.person,
                              size: 36,
                              color: AppColores.oscuro,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  perfil.name ?? 'Usuario',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColores.texto,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildBadgeConexion(perfil),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            perfil.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                          if (distanciaStr != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 14,
                                  color: AppColores.principal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'A $distanciaStr de ti',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColores.principal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColores.divisor),
                        ),
                        child: const Text('Cerrar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _abrirConversacion(perfil);
                        },
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Abrir Chat'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final miPerfil = DataHolder.instance.perfilUsuario;
    final miPos = miPerfil.posicion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa y Cerca de mí'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Centrar en mi ubicación',
            onPressed: () {
              if (miPos != null) {
                _mapController.move(
                  LatLng(miPos.latitude, miPos.longitude),
                  13.0,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Aún no has registrado tu ubicación. Puedes capturarla en "Mi Perfil".',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar perfiles',
            onPressed: _cargarDatos,
          ),
        ],
      ),
      bottomNavigationBar: InsBotBarStyle1(
        iBarIndex: 2,
        sBadge2: DataHolder.instance.sMessagesBadgeText,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior con pestañas y selector de modo
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    icon: Icon(Icons.map_rounded),
                    label: Text('Mapa'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: Icon(Icons.format_list_bulleted_rounded),
                    label: Text('Cerca de mí'),
                  ),
                ],
                selected: {_tabSeleccionada},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _tabSeleccionada = newSelection.first;
                  });
                  if (_tabSeleccionada == 1 && _perfilesCercanos.isEmpty) {
                    _ejecutarOrdenacionEnIsolate();
                  }
                },
              ),
            ),

            // Indicador de cálculo en Isolate no bloqueante (PSP RA2.e)
            if (_calculandoIsolate || _estadoIsolate.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                color: AppColores.suave,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _estadoIsolate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.oscuro,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Contenido dinámico según el modo seleccionado
            Expanded(
              child: _cargandoPerfiles
                  ? const Center(child: CircularProgressIndicator())
                  : (_tabSeleccionada == 0
                        ? _buildMapaView()
                        : _buildListaCercaDeMiView()),
            ),
          ],
        ),
      ),
    );
  }

  /// Comprueba si el contacto está conectado según el estado de Firestore
  bool _estaPerfilConectado(Perfil perfil) {
    return perfil.conectado;
  }

  /// Construye el badge de texto y punto para el estado de conexión
  Widget _buildBadgeConexion(Perfil perfil) {
    final bool estaConectado = _estaPerfilConectado(perfil);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: estaConectado
            ? const Color.fromARGB(255, 232, 248, 235)
            : const Color.fromARGB(255, 240, 240, 240),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: estaConectado ? Colors.green.shade400 : Colors.grey.shade400,
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
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: estaConectado
                  ? Colors.green.shade800
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el marcador visual para el usuario actual (borde azul y avatar propio)
  Widget _buildMarcadorUsuario(Perfil miPerfil) {
    final avatarUrl = miPerfil.urlAvatar;
    final avatarBase64 = miPerfil.avatarBase64;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: CircleAvatar(
              backgroundColor: AppColores.suave,
              backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                  ? MemoryImage(base64Decode(avatarBase64))
                  : ((avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl) as ImageProvider
                        : null),
              child:
                  ((avatarBase64 == null || avatarBase64.isEmpty) &&
                      (avatarUrl == null || avatarUrl.isEmpty))
                  ? const Icon(Icons.person, size: 26, color: AppColores.oscuro)
                  : null,
            ),
          ),
        ),
        // Etiqueta flotante inferior "Tú"
        Positioned(
          bottom: -4,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Text(
                'Tú',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye el marcador visual para un contacto: Avatar + Badge de conexión
  Widget _buildMarcadorContacto(Perfil perfil) {
    final avatarUrl = perfil.urlAvatar;
    final avatarBase64 = perfil.avatarBase64;
    final bool online = _estaPerfilConectado(perfil);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Contenedor principal con sombra y avatar
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColores.principal,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: CircleAvatar(
              backgroundColor: AppColores.suave,
              backgroundImage: (avatarBase64 != null && avatarBase64.isNotEmpty)
                  ? MemoryImage(base64Decode(avatarBase64))
                  : ((avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl) as ImageProvider
                        : null),
              child:
                  ((avatarBase64 == null || avatarBase64.isEmpty) &&
                      (avatarUrl == null || avatarUrl.isEmpty))
                  ? const Icon(Icons.person, size: 24, color: AppColores.oscuro)
                  : null,
            ),
          ),
        ),

        // Badge indicador de conexión en la esquina superior derecha
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? Colors.green : Colors.grey.shade400,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Construye el mapa interactivo con OpenStreetMap y marcadores
  Widget _buildMapaView() {
    final miPerfil = DataHolder.instance.perfilUsuario;
    final miPos = miPerfil.posicion;
    final List<Marker> markers = [];

    // 1. Marcador del usuario actual (con su avatar e insignia azul)
    if (miPos != null) {
      markers.add(
        Marker(
          point: LatLng(miPos.latitude, miPos.longitude),
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Esta es tu ubicación actual registrada.'),
                ),
              );
            },
            child: _buildMarcadorUsuario(miPerfil),
          ),
        ),
      );
    }

    // 2. Marcadores para los demás usuarios que tengan coordenadas
    for (final perfil in _todosLosPerfiles) {
      if (perfil.posicion != null) {
        markers.add(
          Marker(
            point: LatLng(
              perfil.posicion!.latitude,
              perfil.posicion!.longitude,
            ),
            width: 52,
            height: 52,
            child: GestureDetector(
              onTap: () => _mostrarDetallePerfil(perfil),
              child: _buildMarcadorContacto(perfil),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _obtenerCentroMapa(),
            initialZoom: miPos != null ? 12.0 : 6.0,
            maxZoom: 18.0,
            minZoom: 3.0,
          ),
          children: [
            // Capa oficial de teselas OpenStreetMap (Cumple política OSM: userAgentPackageName y HTTPS)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.proyecto_app_pablo_casado',
            ),
            // Capa de marcadores interactivos
            MarkerLayer(markers: markers),
            // Atribución obligatoria de OpenStreetMap (PMDM RA2.k)
            const SimpleAttributionWidget(
              source: Text('© OpenStreetMap contributors'),
              alignment: Alignment.bottomRight,
            ),
          ],
        ),

        // Aviso flotante si el usuario no tiene ubicación aún
        if (miPos == null)
          PositionEventNotice(
            onCapturar: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
      ],
    );
  }

  /// Construye la lista de usuarios ordenados por cercanía calculada en el Isolate
  Widget _buildListaCercaDeMiView() {
    final miPos = DataHolder.instance.perfilUsuario.posicion;

    if (miPos == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 56,
                color: AppColores.textoSecundario,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ubicación no configurada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColores.texto,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Para calcular la distancia relativa con otros usuarios, primero debes registrar tu posición en tu perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColores.textoSecundario),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/edit_profile'),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Configurar mi ubicación'),
              ),
            ],
          ),
        ),
      );
    }

    if (_perfilesCercanos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: AppColores.textoSecundario,
              ),
              const SizedBox(height: 12),
              const Text(
                'Sin contactos con ubicación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColores.texto,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Solo se muestran aquí los contactos con los que mantienes conversaciones activas y que hayan compartido su ubicación.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _perfilesCercanos.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColores.divisor),
      itemBuilder: (context, index) {
        final item = _perfilesCercanos[index];
        final perfil = item.perfil;
        final avatarUrl = perfil.urlAvatar;
        final avatarBase64 = perfil.avatarBase64;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 8,
          ),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColores.suave,
                backgroundImage:
                    (avatarBase64 != null && avatarBase64.isNotEmpty)
                    ? MemoryImage(base64Decode(avatarBase64))
                    : ((avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl) as ImageProvider
                          : null),
                child:
                    ((avatarBase64 == null || avatarBase64.isEmpty) &&
                        (avatarUrl == null || avatarUrl.isEmpty))
                    ? const Icon(Icons.person, color: AppColores.oscuro)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _estaPerfilConectado(perfil)
                        ? Colors.green
                        : Colors.grey.shade400,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  perfil.name ?? 'Usuario',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColores.texto,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _buildBadgeConexion(perfil),
            ],
          ),
          subtitle: Text(
            perfil.email ?? '',
            style: const TextStyle(
              fontSize: 12,
              color: AppColores.textoSecundario,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColores.suave,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColores.divisor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      size: 13,
                      color: AppColores.principal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.distanciaFormateada,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColores.principal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColores.oscuro,
                ),
                tooltip: 'Abrir conversación',
                onPressed: () => _abrirConversacion(perfil),
              ),
            ],
          ),
          onTap: () {
            // Mover el mapa a la posición del contacto seleccionado y cambiar de pestaña
            if (perfil.posicion != null) {
              setState(() {
                _tabSeleccionada = 0;
              });
              _mapController.move(
                LatLng(perfil.posicion!.latitude, perfil.posicion!.longitude),
                14.0,
              );
            }
          },
        );
      },
    );
  }
}

/// Widget auxiliar flotante para avisar al usuario de que capture su GPS
class PositionEventNotice extends StatelessWidget {
  final VoidCallback onCapturar;

  const PositionEventNotice({super.key, required this.onCapturar});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Aún no has registrado tu posición actual.',
                  style: TextStyle(fontSize: 12, color: AppColores.texto),
                ),
              ),
              TextButton(
                onPressed: onCapturar,
                child: const Text('Registrar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
