import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../fb_objects/partida.dart';
import '../fb_objects/perfil.dart';

/// ============================================================================
/// BLOQUE 5: ESTADO DE LA PETICIÓN DE LOCALIZACIÓN
/// ============================================================================
enum LocationResultStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  error,
}

/// Envoltorio tipado con el resultado de la consulta de localización
class LocationResult {
  final LocationResultStatus status;
  final Position? position;
  final String? mensaje;

  LocationResult.success(this.position)
    : status = LocationResultStatus.success,
      mensaje = null;

  LocationResult.failure(this.status, this.mensaje) : position = null;

  bool get isSuccess => status == LocationResultStatus.success;

  /// Retorna las coordenadas convertidas a [GeoPoint] de Firestore
  GeoPoint? get geoPoint => position != null
      ? GeoPoint(position!.latitude, position!.longitude)
      : null;
}

/// ============================================================================
/// BLOQUE 6: MODELO TIPADO DE PERFIL CON DISTANCIA RELATIVA AL USUARIO
/// ============================================================================
class PerfilDistanciaDTO {
  final Perfil perfil;
  final double distanciaKm;

  PerfilDistanciaDTO({required this.perfil, required this.distanciaKm});

  /// Formatea la distancia de manera legible (en metros si < 1 km, en km si >= 1 km)
  String get distanciaFormateada {
    if (distanciaKm < 1.0) {
      final metros = (distanciaKm * 1000).round();
      return '$metros m';
    } else {
      return '${distanciaKm.toStringAsFixed(1)} km';
    }
  }
}

/// ============================================================================
/// BLOQUE 6 MTG: MODELO TIPADO DE PARTIDA / MESA CON DISTANCIA AL JUGADOR
/// ============================================================================
class PartidaDistanciaDTO {
  final Partida partida;
  final double distanciaKm;

  PartidaDistanciaDTO({required this.partida, required this.distanciaKm});

  /// Formatea la distancia de manera legible (en metros si < 1 km, en km si >= 1 km)
  String get distanciaFormateada {
    if (distanciaKm < 1.0) {
      final metros = (distanciaKm * 1000).round();
      return '$metros m';
    } else {
      return '${distanciaKm.toStringAsFixed(1)} km';
    }
  }
}

/// Parámetros transferibles al Isolate para ordenación geográfica de perfiles
class _IsolateDistanceParams {
  final List<Perfil> perfiles;
  final double origenLat;
  final double origenLng;
  final SendPort sendPort;

  _IsolateDistanceParams({
    required this.perfiles,
    required this.origenLat,
    required this.origenLng,
    required this.sendPort,
  });
}

/// Parámetros transferibles al Isolate para ordenación geográfica de partidas MTG
class _IsolatePartidasDistanceParams {
  final List<Partida> partidas;
  final double origenLat;
  final double origenLng;
  final SendPort sendPort;

  _IsolatePartidasDistanceParams({
    required this.partidas,
    required this.origenLat,
    required this.origenLng,
    required this.sendPort,
  });
}

/// Worker puro ejecutado en un Isolate secundario con comunicación bidireccional (0490 PSP RA2.c / RA2.e).
/// Emite mensajes de porcentaje y estado mediante SendPort directamente hacia el hilo principal.
void _ordenarPerfilesIsolateEntry(_IsolateDistanceParams params) {
  final sendPort = params.sendPort;
  final total = params.perfiles.length;

  sendPort.send({
    'tipo': 'progreso',
    'porcentaje': 0.1,
    'mensaje': 'Iniciando cálculo de distancias en Isolate secundario...',
  });

  final List<PerfilDistanciaDTO> lista = [];

  for (int i = 0; i < total; i++) {
    final p = params.perfiles[i];
    if (p.posicion != null) {
      final d = LocationAdmin.calcularDistanciaHaversine(
        params.origenLat,
        params.origenLng,
        p.posicion!.latitude,
        p.posicion!.longitude,
      );
      lista.add(PerfilDistanciaDTO(perfil: p, distanciaKm: d));
    }

    if (total > 0 && (i % (total ~/ 4 + 1) == 0 || i == total - 1)) {
      final progreso = 0.2 + (0.6 * (i + 1) / total);
      sendPort.send({
        'tipo': 'progreso',
        'porcentaje': progreso,
        'mensaje':
            'Calculando distancia Haversine (${i + 1}/$total perfiles)...',
      });
    }
  }

  sendPort.send({
    'tipo': 'progreso',
    'porcentaje': 0.9,
    'mensaje': 'Ordenando perfiles de menor a mayor proximidad...',
  });

  // Ordenación ascendente por cercanía
  lista.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));

  sendPort.send({'tipo': 'resultado', 'datos': lista});
}

/// Worker puro ejecutado en un Isolate secundario para Partidas MTG (0490 PSP RA2.c / RA2.e).
/// Comunica su avance mediante SendPort al ReceivePort del hilo de la interfaz.
void _ordenarPartidasIsolateEntry(_IsolatePartidasDistanceParams params) {
  final sendPort = params.sendPort;
  final total = params.partidas.length;

  sendPort.send({
    'tipo': 'progreso',
    'porcentaje': 0.15,
    'mensaje': 'Iniciando localización de mesas MTG en Isolate...',
  });

  final List<PartidaDistanciaDTO> lista = [];

  for (int i = 0; i < total; i++) {
    final partida = params.partidas[i];
    final d = LocationAdmin.calcularDistanciaHaversine(
      params.origenLat,
      params.origenLng,
      partida.posicion.latitude,
      partida.posicion.longitude,
    );
    lista.add(PartidaDistanciaDTO(partida: partida, distanciaKm: d));

    if (total > 0 && (i % (total ~/ 3 + 1) == 0 || i == total - 1)) {
      final progreso = 0.25 + (0.55 * (i + 1) / total);
      sendPort.send({
        'tipo': 'progreso',
        'porcentaje': progreso,
        'mensaje': 'Calculando distancia geodésica (${i + 1}/$total mesas)...',
      });
    }
  }

  sendPort.send({
    'tipo': 'progreso',
    'porcentaje': 0.9,
    'mensaje': 'Ordenando mesas abiertas por cercanía geográfica...',
  });

  lista.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));

  sendPort.send({'tipo': 'resultado', 'datos': lista});
}

/// ============================================================================
/// SERVICIO CENTRAL DE GEOLOCALIZACIÓN Y CÁLCULO ESPACIAL (LocationAdmin)
/// ============================================================================
class LocationAdmin {
  LocationAdmin();

  // ==========================================================================
  // BLOQUE 6: CÁLCULOS TRIGONOMÉTRICOS Y ORDENACIÓN EN ISOLATE (PSP RA2.c / RA2.e)
  // ==========================================================================

  /// Calcula la distancia ortodrómica en kilómetros entre dos pares de coordenadas
  /// mediante la fórmula del semiverseno (Haversine Formula).
  /// Función matemática pura ejecutable en cualquier hilo sin dependencias de UI.
  static double calcularDistanciaHaversine(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double radioTierraKm = 6371.0; // Radio medio de la Tierra en km

    final double dLat = _gradosARadianes(lat2 - lat1);
    final double dLon = _gradosARadianes(lon2 - lon1);

    final double lat1Rad = _gradosARadianes(lat1);
    final double lat2Rad = _gradosARadianes(lat2);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return radioTierraKm * c;
  }

  static double _gradosARadianes(double grados) => grados * (pi / 180.0);

  /// Ordena síncronamente perfiles (útil para tests unitarios directos y benchmarking)
  static List<PerfilDistanciaDTO> ordenarPerfilesSincrono({
    required List<Perfil> perfiles,
    required double origenLat,
    required double origenLng,
  }) {
    final List<PerfilDistanciaDTO> lista = [];
    for (final p in perfiles) {
      if (p.posicion != null) {
        final d = calcularDistanciaHaversine(
          origenLat,
          origenLng,
          p.posicion!.latitude,
          p.posicion!.longitude,
        );
        lista.add(PerfilDistanciaDTO(perfil: p, distanciaKm: d));
      }
    }
    lista.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return lista;
  }

  /// Ordena síncronamente mesas/partidas MTG (útil para tests unitarios directos)
  static List<PartidaDistanciaDTO> ordenarPartidasSincrono({
    required List<Partida> partidas,
    required double origenLat,
    required double origenLng,
  }) {
    final List<PartidaDistanciaDTO> lista = [];
    for (final p in partidas) {
      final d = calcularDistanciaHaversine(
        origenLat,
        origenLng,
        p.posicion.latitude,
        p.posicion.longitude,
      );
      lista.add(PartidaDistanciaDTO(partida: p, distanciaKm: d));
    }
    lista.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return lista;
  }

  /// Ordena los perfiles por distancia al usuario ejecutando el cálculo en un
  /// ISOLATE SECUNDARIO mediante Isolate.spawn y comunicando el progreso real
  /// a través de SendPort y ReceivePort (0490 PSP RA2.c / RA2.e).
  Future<List<PerfilDistanciaDTO>> ordenarPerfilesPorCercaniaEnIsolate({
    required List<Perfil> perfiles,
    required double origenLat,
    required double origenLng,
    void Function(String estado)? onProgreso,
  }) async {
    if (perfiles.isEmpty) return [];

    if (kIsWeb) {
      onProgreso?.call("Calculando distancias en modo Web...");
      final res = ordenarPerfilesSincrono(
        perfiles: perfiles,
        origenLat: origenLat,
        origenLng: origenLng,
      );
      onProgreso?.call("Completado: ${res.length} perfiles ordenados");
      return res;
    }

    final receivePort = ReceivePort();
    final completer = Completer<List<PerfilDistanciaDTO>>();

    try {
      final isolate = await Isolate.spawn(
        _ordenarPerfilesIsolateEntry,
        _IsolateDistanceParams(
          perfiles: perfiles,
          origenLat: origenLat,
          origenLng: origenLng,
          sendPort: receivePort.sendPort,
        ),
      );

      receivePort.listen((message) {
        if (message is Map) {
          final tipo = message['tipo'];
          if (tipo == 'progreso') {
            final msg = (message['mensaje'] as String?) ?? '';
            onProgreso?.call(msg);
          } else if (tipo == 'resultado') {
            final res = (message['datos'] as List).cast<PerfilDistanciaDTO>();
            receivePort.close();
            isolate.kill(priority: Isolate.immediate);
            completer.complete(res);
          }
        }
      });

      return await completer.future;
    } catch (e) {
      receivePort.close();
      debugPrint(
        "Fallback a ordenación síncrona de perfiles por error en isolate: $e",
      );
      return ordenarPerfilesSincrono(
        perfiles: perfiles,
        origenLat: origenLat,
        origenLng: origenLng,
      );
    }
  }

  /// Ordena las MESAS DE JUEGO MTG por distancia al usuario ejecutando el cálculo en un
  /// ISOLATE SECUNDARIO mediante Isolate.spawn y comunicando el avance porcentual real
  /// a través de SendPort y ReceivePort (0490 PSP RA2.c / RA2.e).
  Future<List<PartidaDistanciaDTO>> ordenarPartidasPorCercaniaEnIsolate({
    required List<Partida> partidas,
    required double origenLat,
    required double origenLng,
    void Function(double porcentaje, String estado)? onProgreso,
  }) async {
    if (partidas.isEmpty) return [];

    if (kIsWeb) {
      onProgreso?.call(0.5, "Calculando distancias a mesas MTG...");
      final res = ordenarPartidasSincrono(
        partidas: partidas,
        origenLat: origenLat,
        origenLng: origenLng,
      );
      onProgreso?.call(1.0, "Mesas ordenadas.");
      return res;
    }

    final receivePort = ReceivePort();
    final completer = Completer<List<PartidaDistanciaDTO>>();

    try {
      final isolate = await Isolate.spawn(
        _ordenarPartidasIsolateEntry,
        _IsolatePartidasDistanceParams(
          partidas: partidas,
          origenLat: origenLat,
          origenLng: origenLng,
          sendPort: receivePort.sendPort,
        ),
      );

      receivePort.listen((message) {
        if (message is Map) {
          final tipo = message['tipo'];
          if (tipo == 'progreso') {
            final pct = (message['porcentaje'] as num?)?.toDouble() ?? 0.0;
            final msg = (message['mensaje'] as String?) ?? '';
            onProgreso?.call(pct, msg);
          } else if (tipo == 'resultado') {
            final res = (message['datos'] as List).cast<PartidaDistanciaDTO>();
            receivePort.close();
            isolate.kill(priority: Isolate.immediate);
            completer.complete(res);
          }
        }
      });

      return await completer.future;
    } catch (e) {
      receivePort.close();
      debugPrint("Fallback síncrono por error en isolate de partidas: $e");
      return ordenarPartidasSincrono(
        partidas: partidas,
        origenLat: origenLat,
        origenLng: origenLng,
      );
    }
  }

  // ==========================================================================
  // BLOQUE 5: GESTIÓN DE PERMISOS Y LECTURA GPS CON GEOLOCATOR
  // ==========================================================================

  /// Comprueba si los servicios de ubicación (GPS) del dispositivo están encendidos
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint("Error comprobando servicio de ubicación: $e");
      return false;
    }
  }

  /// Comprueba el estado actual de los permisos de localización
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint("Error comprobando permisos de localización: $e");
      return LocationPermission.denied;
    }
  }

  /// Solicita interactivamente el permiso de localización al usuario (*just-in-time*)
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint("Error solicitando permisos de localización: $e");
      return LocationPermission.denied;
    }
  }

  /// Abre la pantalla de ajustes de la aplicación en el sistema operativo
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint("Error abriendo ajustes de la aplicación: $e");
      return false;
    }
  }

  /// Abre la pantalla de configuración del servicio de ubicación en el sistema
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint("Error abriendo ajustes de ubicación: $e");
      return false;
    }
  }

  /// Obtiene la posición geográfica actual del usuario de forma resiliente.
  /// Implementa:
  /// - RF-03: Detección y notificación si el GPS está apagado.
  /// - RF-04: Gestión interactiva de permisos denegados o denegados para siempre.
  /// - RF-05: Timeout estricto de [timeout] (10s por defecto) sin congelar la app.
  Future<LocationResult> obtenerPosicionActual({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 1. Verificar si los servicios de ubicación están encendidos
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.failure(
        LocationResultStatus.serviceDisabled,
        "Los servicios de ubicación (GPS) están desactivados. Por favor, actívalos en los ajustes.",
      );
    }

    // 2. Verificar y solicitar permisos de forma interactiva (JIT)
    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult.failure(
          LocationResultStatus.permissionDenied,
          "Permiso de ubicación denegado por el usuario.",
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult.failure(
        LocationResultStatus.permissionDeniedForever,
        "Los permisos de ubicación están denegados permanentemente. Puedes habilitarlos en los ajustes de la aplicación.",
      );
    }

    // 3. Adquirir la posición con timeout controlado de 10s
    try {
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      return LocationResult.success(position);
    } on TimeoutException {
      // RF-05: Tiempo de espera agotado sin congelar la app
      debugPrint(
        "LocationAdmin: Timeout de $timeout agotado al obtener posición.",
      );
      return LocationResult.failure(
        LocationResultStatus.timeout,
        "Tiempo de espera agotado al consultar la ubicación satelital/red.",
      );
    } catch (e) {
      debugPrint("LocationAdmin: Error inesperado obteniendo posición: $e");
      return LocationResult.failure(
        LocationResultStatus.error,
        "Error inesperado al obtener la ubicación: $e",
      );
    }
  }
}
