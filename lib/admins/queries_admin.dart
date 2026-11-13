import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../fb_objects/perfil.dart';

/// DTO que encapsula el resultado de una consulta paginada de perfiles
class ResultadoPaginacionPerfil {
  final List<Perfil> perfiles;
  final DocumentSnapshot? ultimoDocumento;
  final bool hayMas;

  ResultadoPaginacionPerfil({
    required this.perfiles,
    required this.ultimoDocumento,
    required this.hayMas,
  });
}

/// ============================================================================
/// GESTOR DE CONSULTAS AVANZADAS EN FIRESTORE (QueriesAdmin)
/// ============================================================================
/// Implementa las 4 consultas de base de datos requeridas por la rúbrica
/// (0486 AD RA4.e · RA4.g):
/// 1. where con 2 condiciones (conectado == true && edad >= min)
/// 2. orderBy con limit (perfiles registrados más recientes)
/// 3. rango sobre fecha (fechaRegistro entre dos fechas)
/// 4. paginación con startAfterDocument
///
/// Además provee un mecanismo para asegurar >= 20 documentos de prueba.
class QueriesAdmin {
  /// Acceso perezoso a Firestore para facilitar tests unitarios
  FirebaseFirestore get db => FirebaseFirestore.instance;

  /// Referencia a la colección "Perfiles" con conversor fuertemente tipado
  CollectionReference<Perfil> get _perfilesRef => db
      .collection("Perfiles")
      .withConverter<Perfil>(
        fromFirestore: Perfil.fromFirestore,
        toFirestore: (Perfil p, _) => p.toFirestore(),
      );

  // ==========================================================================
  // CONSULTA 1: where con 2 condiciones (0486 AD RA4.e · RA4.g)
  // Requiere índice compuesto en firestore.indexes.json:
  //   colección "Perfiles", campos: conectado (ASC), edad (ASC)
  // ==========================================================================
  Future<List<Perfil>> consultarConectadosMayoresDeEdad({
    int edadMinima = 18,
  }) async {
    try {
      final querySnapshot = await _perfilesRef
          .where("conectado", isEqualTo: true)
          .where("edad", isGreaterThanOrEqualTo: edadMinima)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error en consulta 1 (where doble condición): $e");
      rethrow;
    }
  }

  // ==========================================================================
  // CONSULTA 2: orderBy con limit (0486 AD RA4.e · RA4.g)
  // Obtiene los N perfiles registrados más recientemente ordenados por fecha
  // ==========================================================================
  Future<List<Perfil>> consultarMasRecientes({int limite = 5}) async {
    try {
      final querySnapshot = await _perfilesRef
          .orderBy("fechaRegistro", descending: true)
          .limit(limite)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error en consulta 2 (orderBy + limit): $e");
      rethrow;
    }
  }

  // ==========================================================================
  // CONSULTA 3: Rango sobre una fecha (0486 AD RA4.e · RA4.g)
  // Filtra perfiles cuya fecha de registro esté dentro del intervalo [inicio, fin]
  // ==========================================================================
  Future<List<Perfil>> consultarPorRangoFechas({
    required DateTime inicio,
    required DateTime fin,
  }) async {
    try {
      final tsInicio = Timestamp.fromDate(inicio);
      final tsFin = Timestamp.fromDate(fin);

      final querySnapshot = await _perfilesRef
          .where("fechaRegistro", isGreaterThanOrEqualTo: tsInicio)
          .where("fechaRegistro", isLessThanOrEqualTo: tsFin)
          .orderBy("fechaRegistro", descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error en consulta 3 (rango fecha): $e");
      rethrow;
    }
  }

  // ==========================================================================
  // CONSULTA 4: Paginación con startAfterDocument (0486 AD RA4.e · RA4.g)
  // Carga perfiles ordenados por nombre en lotes de tamaño `limite`.
  // Si se provee `ultimoDocumento`, inicia la siguiente página justo después.
  // ==========================================================================
  Future<ResultadoPaginacionPerfil> consultarPaginado({
    DocumentSnapshot? ultimoDocumento,
    int limite = 5,
  }) async {
    try {
      Query<Perfil> query = _perfilesRef.orderBy("name").limit(limite);

      if (ultimoDocumento != null) {
        query = query.startAfterDocument(ultimoDocumento);
      }

      final querySnapshot = await query.get();
      final List<Perfil> perfiles = querySnapshot.docs
          .map((doc) => doc.data())
          .toList();

      final DocumentSnapshot? nuevoUltimo = querySnapshot.docs.isNotEmpty
          ? querySnapshot.docs.last
          : null;

      final bool hayMas = querySnapshot.docs.length == limite;

      return ResultadoPaginacionPerfil(
        perfiles: perfiles,
        ultimoDocumento: nuevoUltimo,
        hayMas: hayMas,
      );
    } catch (e) {
      debugPrint("Error en consulta 4 (paginación startAfterDocument): $e");
      rethrow;
    }
  }

  // ==========================================================================
  // SEMBRADO DE 20 PERFILES DE PRUEBA (0486 AD RA4.d · RA4.i)
  // Asegura que la colección tenga al menos 20 documentos para evaluar
  // las 4 consultas y la paginación sin depender de registros manuales.
  // Ubicaciones distribuidas en Madrid, Corredor del Henares y Guadalajara.
  // ==========================================================================
  Future<int> sembrar20PerfilesPrueba({bool forzar = false}) async {
    try {
      final existentes = await db.collection("Perfiles").limit(25).get();
      if (!forzar && existentes.docs.length >= 20) {
        debugPrint(
          "La colección Perfiles ya cuenta con ${existentes.docs.length} documentos. No se requiere sembrado.",
        );
        return existentes.docs.length;
      }

      final batch = db.batch();
      final ahora = DateTime.now();

      // 20 perfiles distribuidos a lo largo del eje Madrid - Corredor del Henares - Guadalajara
      final List<Map<String, dynamic>> perfilesMock = [
        {
          "name": "Alejandro Sanz",
          "edad": 28,
          "email": "alejandro@ejemplo.com",
          "conectado": true,
          "diasAtras": 2,
          // Madrid - Puerta del Sol / Centro
          "lat": 40.4168,
          "lng": -3.7038,
        },
        {
          "name": "Beatriz Morales",
          "edad": 22,
          "email": "beatriz@ejemplo.com",
          "conectado": false,
          "diasAtras": 5,
          // Madrid - Parque del Retiro
          "lat": 40.4153,
          "lng": -3.6844,
        },
        {
          "name": "Carlos Ruiz",
          "edad": 35,
          "email": "carlos@ejemplo.com",
          "conectado": true,
          "diasAtras": 8,
          // Madrid - Plaza de Castilla / Chamartín
          "lat": 40.4665,
          "lng": -3.6892,
        },
        {
          "name": "Diana Navarro",
          "edad": 19,
          "email": "diana@ejemplo.com",
          "conectado": true,
          "diasAtras": 10,
          // Madrid - Moncloa
          "lat": 40.4350,
          "lng": -3.7190,
        },
        {
          "name": "Eduardo Ramos",
          "edad": 42,
          "email": "eduardo@ejemplo.com",
          "conectado": false,
          "diasAtras": 12,
          // Madrid - Vallecas
          "lat": 40.3920,
          "lng": -3.6580,
        },
        {
          "name": "Fátima Castro",
          "edad": 26,
          "email": "fatima@ejemplo.com",
          "conectado": true,
          "diasAtras": 14,
          // Corredor del Henares - Coslada Centro
          "lat": 40.4260,
          "lng": -3.5650,
        },
        {
          "name": "Guillermo Gil",
          "edad": 31,
          "email": "guillermo@ejemplo.com",
          "conectado": false,
          "diasAtras": 16,
          // Corredor del Henares - San Fernando de Henares
          "lat": 40.4250,
          "lng": -3.5350,
        },
        {
          "name": "Helena Ortiz",
          "edad": 24,
          "email": "helena@ejemplo.com",
          "conectado": true,
          "diasAtras": 18,
          // Corredor del Henares - Torrejón de Ardoz (Plaza Mayor)
          "lat": 40.4570,
          "lng": -3.4780,
        },
        {
          "name": "Ignacio Vega",
          "edad": 38,
          "email": "ignacio@ejemplo.com",
          "conectado": false,
          "diasAtras": 20,
          // Corredor del Henares - Torrejón de Ardoz (Parque Europa)
          "lat": 40.4485,
          "lng": -3.4680,
        },
        {
          "name": "Julia Méndez",
          "edad": 21,
          "email": "julia@ejemplo.com",
          "conectado": true,
          "diasAtras": 22,
          // Corredor del Henares - Alcalá de Henares (Plaza de Cervantes)
          "lat": 40.4818,
          "lng": -3.3644,
        },
        {
          "name": "Kevin Lozano",
          "edad": 29,
          "email": "kevin@ejemplo.com",
          "conectado": false,
          "diasAtras": 25,
          // Corredor del Henares - Alcalá de Henares (La Garena)
          "lat": 40.4860,
          "lng": -3.3850,
        },
        {
          "name": "Laura Serrano",
          "edad": 27,
          "email": "laura@ejemplo.com",
          "conectado": true,
          "diasAtras": 28,
          // Corredor del Henares - Alcalá de Henares (Espartales)
          "lat": 40.5050,
          "lng": -3.3600,
        },
        {
          "name": "Manuel Delgado",
          "edad": 45,
          "email": "manuel@ejemplo.com",
          "conectado": false,
          "diasAtras": 32,
          // Corredor del Henares - Alcalá de Henares (Campus Universidad)
          "lat": 40.5120,
          "lng": -3.3480,
        },
        {
          "name": "Nuria Gallego",
          "edad": 23,
          "email": "nuria@ejemplo.com",
          "conectado": true,
          "diasAtras": 35,
          // Corredor del Henares - Meco
          "lat": 40.5520,
          "lng": -3.3280,
        },
        {
          "name": "Óscar Iglesias",
          "edad": 33,
          "email": "oscar@ejemplo.com",
          "conectado": false,
          "diasAtras": 40,
          // Corredor del Henares - Azuqueca de Henares (Estación)
          "lat": 40.5640,
          "lng": -3.2680,
        },
        {
          "name": "Patricia Marín",
          "edad": 30,
          "email": "patricia@ejemplo.com",
          "conectado": true,
          "diasAtras": 45,
          // Corredor del Henares - Azuqueca de Henares (Vallehermoso)
          "lat": 40.5730,
          "lng": -3.2550,
        },
        {
          "name": "Quique Vidal",
          "edad": 20,
          "email": "quique@ejemplo.com",
          "conectado": false,
          "diasAtras": 50,
          // Corredor del Henares - Alovera
          "lat": 40.5960,
          "lng": -3.2480,
        },
        {
          "name": "Rocío Medina",
          "edad": 36,
          "email": "rocio@ejemplo.com",
          "conectado": true,
          "diasAtras": 55,
          // Corredor del Henares - Cabanillas del Campo
          "lat": 40.6380,
          "lng": -3.2340,
        },
        {
          "name": "Sergio Cano",
          "edad": 40,
          "email": "sergio@ejemplo.com",
          "conectado": false,
          "diasAtras": 60,
          // Guadalajara - Palacio del Infantado
          "lat": 40.6360,
          "lng": -3.1690,
        },
        {
          "name": "Teresa Blanco",
          "edad": 25,
          "email": "teresa@ejemplo.com",
          "conectado": true,
          "diasAtras": 65,
          // Guadalajara - Plaza Mayor / Centro
          "lat": 40.6330,
          "lng": -3.1670,
        },
      ];

      int creados = 0;
      for (int i = 0; i < perfilesMock.length; i++) {
        final mock = perfilesMock[i];
        final idDoc = "mock_user_${(i + 1).toString().padLeft(2, '0')}";
        final bool isConectado = mock["conectado"] as bool;
        final fechaReg = ahora.subtract(
          Duration(days: mock["diasAtras"] as int),
        );
        // Si está conectado, su última conexión es ahora mismo; si no, su fecha de registro
        final fechaUltima = isConectado ? ahora : fechaReg;

        final docRef = db.collection("Perfiles").doc(idDoc);
        batch.set(docRef, {
          "uid": idDoc,
          "name": mock["name"],
          "edad": mock["edad"],
          "email": mock["email"],
          "conectado": isConectado,
          "fechaRegistro": Timestamp.fromDate(fechaReg),
          "ultimaConexion": Timestamp.fromDate(fechaUltima),
          "primerLogin": false,
          "posicion": GeoPoint(mock["lat"] as double, mock["lng"] as double),
          "fechaPosicion": Timestamp.fromDate(fechaReg),
          "urlAvatar": null,
          "avatarBase64": null,
        }, SetOptions(merge: true));
        creados++;
      }

      await batch.commit();
      debugPrint(
        "Sembrado completado: $creados perfiles de prueba creados o actualizados.",
      );
      return creados;
    } catch (e) {
      debugPrint("Error sembrando perfiles de prueba: $e");
      rethrow;
    }
  }

  /// Elimina en lote todos los perfiles de prueba sembrados (mock_user_01..20),
  /// preservando intactos los perfiles reales de los usuarios.
  Future<int> eliminarPerfilesSembrados() async {
    try {
      final batch = db.batch();
      int eliminados = 0;

      for (int i = 1; i <= 20; i++) {
        final idDoc = "mock_user_${i.toString().padLeft(2, '0')}";
        final docRef = db.collection("Perfiles").doc(idDoc);
        batch.delete(docRef);
        eliminados++;
      }

      await batch.commit();
      debugPrint("Eliminados $eliminados perfiles mock de prueba.");
      return eliminados;
    } catch (e) {
      debugPrint("Error al eliminar perfiles mock: $e");
      rethrow;
    }
  }
}
