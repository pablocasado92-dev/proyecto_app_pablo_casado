import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

/// Parámetros transferibles al Isolate para ordenación geográfica
class _IsolateDistanceParams {
  final List<Perfil> perfiles;
  final double origenLat;
  final double origenLng;

  _IsolateDistanceParams({
    required this.perfiles,
    required this.origenLat,
    required this.origenLng,
  });
}

/// Worker puro de nivel superior ejecutado en un Isolate secundario (0490 PSP RA2.c)
List<PerfilDistanciaDTO> _ordenarPerfilesWorker(_IsolateDistanceParams params) {
  final List<PerfilDistanciaDTO> lista = [];

  for (final p in params.perfiles) {
    if (p.posicion != null) {
      final d = LocationAdmin.calcularDistanciaHaversine(
        params.origenLat,
        params.origenLng,
        p.posicion!.latitude,
        p.posicion!.longitude,
      );
      lista.add(PerfilDistanciaDTO(perfil: p, distanciaKm: d));
    }
  }

  // Ordenación ascendente (de menor a mayor distancia)
  lista.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
  return lista;
}

/// ============================================================================
/// SERVICIO CENTRAL DE GEOLOCALIZACIÓN Y CÁLCULO ESPACIAL (LocationAdmin)
/// ============================================================================
class LocationAdmin {
  LocationAdmin();

  // ==========================================================================
  // BLOQUE 6: CÁLCULOS TRIGONOMÉTRICOS Y ORDENACIÓN EN ISOLATE (PSP RA2.c)
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

  /// Ordena síncronamente (útil para tests unitarios directos y benchmarking)
  static List<PerfilDistanciaDTO> ordenarPerfilesSincrono({
    required List<Perfil> perfiles,
    required double origenLat,
    required double origenLng,
  }) {
    return _ordenarPerfilesWorker(
      _IsolateDistanceParams(
        perfiles: perfiles,
        origenLat: origenLat,
        origenLng: origenLng,
      ),
    );
  }

  /// Ordena los perfiles por distancia al usuario ejecutando el cálculo en un
  /// ISOLATE SECUNDARIO (compute) para no bloquear el UI thread (0490 PSP RA2.c / RA2.e).
  Future<List<PerfilDistanciaDTO>> ordenarPerfilesPorCercaniaEnIsolate({
    required List<Perfil> perfiles,
    required double origenLat,
    required double origenLng,
    void Function(String estado)? onProgreso,
  }) async {
    onProgreso?.call(
      "Iniciando cálculo de distancias en Isolate secundario...",
    );

    final params = _IsolateDistanceParams(
      perfiles: perfiles,
      origenLat: origenLat,
      origenLng: origenLng,
    );

    List<PerfilDistanciaDTO> resultado;
    if (kIsWeb) {
      // En Flutter Web (JavaScript/Wasm de hilo único), compute se ejecuta en microtask asíncrona
      resultado = _ordenarPerfilesWorker(params);
    } else {
      // En plataformas móviles reales (Android/iOS) compute instancia un Isolate con memoria aislada
      resultado = await compute(_ordenarPerfilesWorker, params);
    }

    onProgreso?.call(
      "Cálculo completado: ${resultado.length} perfiles ordenados",
    );
    return resultado;
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
