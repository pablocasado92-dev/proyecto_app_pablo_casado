import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../fb_objects/partida.dart';
import '../fb_objects/perfil.dart';
import 'storage_admin.dart';

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

/// DTO que encapsula el resultado de una consulta paginada de mesas/partidas MTG
class ResultadoPaginacionPartida {
  final List<Partida> partidas;
  final DocumentSnapshot? ultimoDocumento;
  final bool hayMas;

  ResultadoPaginacionPartida({
    required this.partidas,
    required this.ultimoDocumento,
    required this.hayMas,
  });
}

/// ============================================================================
/// GESTOR DE CONSULTAS AVANZADAS EN FIRESTORE (QueriesAdmin)
/// ============================================================================
/// Implementa las 4 consultas de base de datos requeridas por la rúbrica
/// (0486 AD RA4.e · RA4.g) para mesas de juego (Partidas) y perfiles:
/// 1. where con 2 condiciones (estado == 'abierta' && formato == 'Commander')
/// 2. orderBy con limit (próximas partidas programadas)
/// 3. rango sobre fecha (partidas en los próximos días/semana)
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

  /// Referencia a la colección "Partidas" con conversor fuertemente tipado
  CollectionReference<Partida> get _partidasRef => db
      .collection("Partidas")
      .withConverter<Partida>(
        fromFirestore: Partida.fromFirestore,
        toFirestore: (Partida p, _) => p.toFirestore(),
      );

  // ==========================================================================
  // CONSULTAS AVANZADAS DE MESAS MTG (Partidas) — 0486 AD RA4.e · RA4.g
  // ==========================================================================

  /// CONSULTA 1: where con 2 condiciones (estado y formato MTG)
  /// Requiere índice compuesto en firestore.indexes.json:
  ///   colección "Partidas", campos: estado (ASC), formato (ASC)
  Future<List<Partida>> consultarPartidasPorEstadoYFormato({
    String estado = 'abierta',
    String formato = 'Commander',
  }) async {
    try {
      final querySnapshot = await _partidasRef
          .where("estado", isEqualTo: estado)
          .where("formato", isEqualTo: formato)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error en consulta 1 partidas (where doble condición): $e");
      rethrow;
    }
  }

  /// CONSULTA 2: orderBy con limit (próximas N partidas cronológicamente)
  Future<List<Partida>> consultarProximasPartidas({int limite = 5}) async {
    try {
      final querySnapshot = await _partidasRef
          .where("estado", isEqualTo: "abierta")
          .orderBy("fechaHora", descending: false)
          .limit(limite)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error en consulta 2 partidas (orderBy + limit): $e");
      rethrow;
    }
  }

  /// CONSULTA 3: Rango sobre Timestamp (partidas entre dos fechas)
  Future<List<Partida>> consultarPartidasPorRangoFechas({
    required DateTime inicio,
    required DateTime fin,
  }) async {
    try {
      final tsInicio = Timestamp.fromDate(inicio);
      final tsFin = Timestamp.fromDate(fin);

      final querySnapshot = await _partidasRef
          .where("fechaHora", isGreaterThanOrEqualTo: tsInicio)
          .where("fechaHora", isLessThanOrEqualTo: tsFin)
          .orderBy("fechaHora", descending: false)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error en consulta 3 partidas (rango fecha): $e");
      rethrow;
    }
  }

  /// CONSULTA 4: Paginación con startAfterDocument de mesas MTG
  Future<ResultadoPaginacionPartida> consultarPartidasPaginadas({
    DocumentSnapshot? ultimoDocumento,
    int limite = 5,
  }) async {
    try {
      Query<Partida> query = _partidasRef.orderBy("titulo").limit(limite);

      if (ultimoDocumento != null) {
        query = query.startAfterDocument(ultimoDocumento);
      }

      final querySnapshot = await query.get();
      final List<Partida> partidas = querySnapshot.docs
          .map((doc) => doc.data())
          .toList();

      final DocumentSnapshot? nuevoUltimo = querySnapshot.docs.isNotEmpty
          ? querySnapshot.docs.last
          : null;

      final bool hayMas = querySnapshot.docs.length == limite;

      return ResultadoPaginacionPartida(
        partidas: partidas,
        ultimoDocumento: nuevoUltimo,
        hayMas: hayMas,
      );
    } catch (e) {
      debugPrint("Error en consulta 4 partidas (paginación): $e");
      rethrow;
    }
  }

  /// Permite a un jugador unirse a una mesa abierta si hay plazas disponibles
  Future<bool> unirseAPartida({
    required String partidaId,
    required String userUid,
  }) async {
    try {
      final docRef = db.collection("Partidas").doc(partidaId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return false;

      final data = snapshot.data();
      final List<dynamic> jugadores = data?['jugadoresUIDs'] ?? [];
      final int maxJugadores = (data?['maxJugadores'] as num?)?.toInt() ?? 4;

      if (jugadores.contains(userUid)) return true; // Ya apuntado
      if (jugadores.length >= maxJugadores) return false; // Mesa llena

      await docRef.update({
        "jugadoresUIDs": FieldValue.arrayUnion([userUid]),
      });
      return true;
    } catch (e) {
      debugPrint("Error al unirse a la partida: $e");
      return false;
    }
  }

  /// Permite a un jugador desapuntarse de una mesa
  Future<bool> abandonarPartida({
    required String partidaId,
    required String userUid,
  }) async {
    try {
      final docRef = db.collection("Partidas").doc(partidaId);
      await docRef.update({
        "jugadoresUIDs": FieldValue.arrayRemove([userUid]),
      });
      return true;
    } catch (e) {
      debugPrint("Error al abandonar partida: $e");
      return false;
    }
  }

  /// Crea o actualiza una partida en Firestore
  Future<void> guardarPartida(Partida partida) async {
    await db
        .collection("Partidas")
        .doc(partida.id)
        .set(partida.toFirestore(), SetOptions(merge: true));
  }

  /// Elimina una partida de Firestore
  Future<void> eliminarPartida(String partidaId) async {
    await db.collection("Partidas").doc(partidaId).delete();
  }

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

      // 20 duelistas MTG distribuidos a lo largo del eje Madrid - Corredor del Henares - Guadalajara
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
          "formatos": ["Commander", "Modern"],
          "nivel": "Competitivo",
          "bio":
              "Jugador veterano de Modern (Izzet Murktide) y Commander casual.",
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
          "formatos": ["Commander", "Pauper"],
          "nivel": "Casual",
          "bio": "Amante del lore de Ravnica y de partidas amistosas de Commander en parques.",
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
          "formatos": ["Pioneer", "Standard"],
          "nivel": "Competitivo",
          "bio": "Regular de Store Championships y torneos locales de tienda en Madrid.",
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
          "formatos": ["Commander", "Draft"],
          "nivel": "Iniciación",
          "bio": "Empecé con el kit de inicio de Bloomburrow. Buscando playgroup universitario.",
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
          "formatos": ["Premodern", "Legacy"],
          "nivel": "Competitivo",
          "bio": "Jugando desde 1996. Especialista en formatos Eternal y mazos antiguos.",
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
          "formatos": ["Commander", "Modern"],
          "nivel": "Casual",
          "bio": "Mazo favorito: Atraxa Superfriends. Lista para jugar entre semana en Coslada.",
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
          "formatos": ["Pauper", "Commander"],
          "nivel": "Casual",
          "bio": "Fanático de las comunes de Pauper (Burn, Kuldotha) y partidas distendidas.",
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
          "formatos": ["Commander", "Standard"],
          "nivel": "Iniciación",
          "bio": "Organizo quedadas de Commander en Torrejón. Nuevos jugadores bienvenidos.",
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
          "formatos": ["Modern", "Pioneer"],
          "nivel": "Competitivo",
          "bio":
              "Testeo competitivo para Regional Championship Qualifiers (RCQ).",
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
          "formatos": ["Commander", "Draft"],
          "nivel": "Casual",
          "bio": "Siempre disponible para un draft de fin de semana o una mesa de 4 en Alcalá.",
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
          "formatos": ["Modern", "Legacy"],
          "nivel": "Competitivo",
          "bio": "Juego Yawgmoth en Modern y Death & Taxes en Legacy.",
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
          "formatos": ["Commander"],
          "nivel": "Casual",
          "bio":
              "Tengo 5 barajas de Commander preparadas (nivel de poder 6-7).",
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
          "formatos": ["Premodern", "Commander"],
          "nivel": "Casual",
          "bio": "Planeswalker de la vieja escuela. Me gusta probar comandantes poco habituales.",
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
          "formatos": ["Pauper", "Standard"],
          "nivel": "Iniciación",
          "bio": "Disfruto los mazos de control y aprender las mecánicas de cada colección.",
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
          "formatos": ["Modern", "Commander"],
          "nivel": "Competitivo",
          "bio": "Constante viajero en tren entre Guadalajara y Madrid buscando torneos.",
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
          "formatos": ["Commander", "Draft"],
          "nivel": "Casual",
          "bio": "Cubo draft personal y tardes de Commander entre amigos en Azuqueca.",
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
          "formatos": ["Pioneer", "Standard"],
          "nivel": "Iniciación",
          "bio":
              "Explorando MTG Arena y buscando dar el salto a cartas físicas.",
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
          "formatos": ["Commander", "Modern"],
          "nivel": "Casual",
          "bio": "Juego mazos temáticos de elfos y dragones. Buena onda y diversión asegurada.",
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
          "formatos": ["Legacy", "Modern"],
          "nivel": "Competitivo",
          "bio": "Comunidad MTG Guadalajara. Coordinador de eventos en el club local.",
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
          "formatos": ["Commander", "Pauper"],
          "nivel": "Casual",
          "bio": "Commander tribal de gatos y vampiros. Siempre con barajas de sobra para prestar.",
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
          "formatosPreferidos": mock["formatos"] ?? ["Commander"],
          "nivelJuego": mock["nivel"] ?? "Casual",
          "biografiaMTG":
              mock["bio"] ?? "Planeswalker activo en la comunidad MTG",
        }, SetOptions(merge: true));
        creados++;
      }

      await batch.commit();
      await sembrarPartidasPrueba();
      debugPrint(
        "Sembrado completado: $creados perfiles y mesas MTG creados o actualizados.",
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

      // Eliminar también las partidas mock
      for (int i = 1; i <= 4; i++) {
        final docRef = db.collection("Partidas").doc("partida_mock_0$i");
        batch.delete(docRef);
      }

      await batch.commit();
      debugPrint(
        "Eliminados $eliminados perfiles mock de prueba y partidas mock.",
      );
      return eliminados;
    } catch (e) {
      debugPrint("Error al eliminar perfiles mock: $e");
      rethrow;
    }
  }

  /// Sembrado de 20 partidas y mesas temáticas de MTG en tiendas y clubes locales
  Future<int> sembrarPartidasPrueba() async {
    try {
      final batch = db.batch();
      final ahora = DateTime.now();

      final List<Map<String, dynamic>> partidasMock = [
        {
          "id": "partida_mock_01",
          "titulo": "Mesa Commander Casual 4P",
          "formato": "Commander",
          "creadorUID": "mock_user_01",
          "creadorNombre": "Alejandro Sanz",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_01", "mock_user_06"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(hours: 4))),
          "ubicacionNombre": "Tienda Generación X (Madrid Centro)",
          "posicion": const GeoPoint(40.4200, -3.7050),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion": "Nivel de poder 6-7. Rule 0 amistosa sin combos infinitos turno 3.",
        },
        {
          "id": "partida_mock_02",
          "titulo": "Torneo Modern Semanal",
          "formato": "Modern",
          "creadorUID": "mock_user_03",
          "creadorNombre": "Carlos Ruiz",
          "maxJugadores": 16,
          "jugadoresUIDs": ["mock_user_03", "mock_user_11", "mock_user_15"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 1, hours: 2)),
          ),
          "ubicacionNombre": "El Duende Juegos (Alcalá de Henares)",
          "posicion": const GeoPoint(40.4830, -3.3660),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion":
              "Suizo 4 rondas. Premios en sobres de Modern Horizons 3.",
        },
        {
          "id": "partida_mock_03",
          "titulo": "Pauper League & Quedada",
          "formato": "Pauper",
          "creadorUID": "mock_user_07",
          "creadorNombre": "Guillermo Gil",
          "maxJugadores": 8,
          "jugadoresUIDs": ["mock_user_07", "mock_user_14"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 2))),
          "ubicacionNombre": "Club MTG Henares (Torrejón de Ardoz)",
          "posicion": const GeoPoint(40.4580, -3.4750),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion": "Trae tus barajas de comunes favoritas para testear.",
        },
        {
          "id": "partida_mock_04",
          "titulo": "Commander Pod Nocturno",
          "formato": "Commander",
          "creadorUID": "mock_user_19",
          "creadorNombre": "Sergio Cano",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_19", "mock_user_20"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(hours: 6))),
          "ubicacionNombre": "Asociación Juvenil Guadalajara",
          "posicion": const GeoPoint(40.6350, -3.1680),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion": "Mesa abierta para terminar la semana jugando casual.",
        },
        {
          "id": "partida_mock_05",
          "titulo": "Draft Booster Chaos",
          "formato": "Draft/Limited",
          "creadorUID": "mock_user_05",
          "creadorNombre": "Eduardo Blanco",
          "maxJugadores": 8,
          "jugadoresUIDs": ["mock_user_05", "mock_user_02", "mock_user_08"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 3))),
          "ubicacionNombre": "Itaca Freak Shop (Madrid Moncloa)",
          "posicion": const GeoPoint(40.4350, -3.7180),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion":
              "Draft de 3 sobres de colecciones variadas. Premios a top 3.",
        },
        {
          "id": "partida_mock_06",
          "titulo": "Pioneer Store Championship",
          "formato": "Pioneer",
          "creadorUID": "mock_user_09",
          "creadorNombre": "Irene Lozano",
          "maxJugadores": 12,
          "jugadoresUIDs": ["mock_user_09", "mock_user_13", "mock_user_17"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 4))),
          "ubicacionNombre": "Padis Store (Madrid Chamberí)",
          "posicion": const GeoPoint(40.4390, -3.7020),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion": "Torneo oficial WPN Pioneer con promos exclusivas.",
        },
        {
          "id": "partida_mock_07",
          "titulo": "Iniciación MTG y Barajas Precon",
          "formato": "Standard",
          "creadorUID": "mock_user_04",
          "creadorNombre": "Diana Navarro",
          "maxJugadores": 6,
          "jugadoresUIDs": ["mock_user_04"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 1, hours: 5)),
          ),
          "ubicacionNombre": "Ludoteca Coslada Juega (Coslada)",
          "posicion": const GeoPoint(40.4260, -3.5650),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion": "Encuentro pensado para aprender a jugar o probar barajas básicas.",
        },
        {
          "id": "partida_mock_08",
          "titulo": "Commander cEDH High Stakes",
          "formato": "Commander",
          "creadorUID": "mock_user_11",
          "creadorNombre": "Kiko Rivas",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_11", "mock_user_12", "mock_user_15"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 2, hours: 3)),
          ),
          "ubicacionNombre": "MageStore (Alcalá de Henares Casco)",
          "posicion": const GeoPoint(40.4815, -3.3640),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion":
              "Tier 1 cEDH. Proxies permitidas según normativa oficial.",
        },
        {
          "id": "partida_mock_09",
          "titulo": "Premodern Nostalgia Cup",
          "formato": "Premodern",
          "creadorUID": "mock_user_13",
          "creadorNombre": "Manuel Ortega",
          "maxJugadores": 8,
          "jugadoresUIDs": ["mock_user_13", "mock_user_01"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 5))),
          "ubicacionNombre": "Café Dados & Cartas (Azuqueca de Henares)",
          "posicion": const GeoPoint(40.5640, -3.2680),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion":
              "Cartas marco antiguo 1995-2003. Formato clásico entre amigos.",
        },
        {
          "id": "partida_mock_10",
          "titulo": "Commander Tribal Wars 4P",
          "formato": "Commander",
          "creadorUID": "mock_user_02",
          "creadorNombre": "Beatriz Morales",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_02", "mock_user_10"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 1, hours: 8)),
          ),
          "ubicacionNombre": "Parque del Retiro (Terraza Abierta Madrid)",
          "posicion": const GeoPoint(40.4153, -3.6844),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion":
              "Mesas de temática tribal (Elfos, Goblins, Dragones, Zombis).",
        },
        {
          "id": "partida_mock_11",
          "titulo": "Modern Open Trial",
          "formato": "Modern",
          "creadorUID": "mock_user_15",
          "creadorNombre": "Óscar Iglesias",
          "maxJugadores": 16,
          "jugadoresUIDs": ["mock_user_15", "mock_user_03", "mock_user_11"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 6))),
          "ubicacionNombre": "Evolution Store (Madrid Nuevos Ministerios)",
          "posicion": const GeoPoint(40.4460, -3.6920),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion": "Testeo competitivo de banquillo y metajuego moderno.",
        },
        {
          "id": "partida_mock_12",
          "titulo": "Commander 2 Headed Giant",
          "formato": "Commander",
          "creadorUID": "mock_user_06",
          "creadorNombre": "Fabiola Crespo",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_06", "mock_user_08"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 2, hours: 6)),
          ),
          "ubicacionNombre": "Ludoteca San Fernando (San Fernando de Henares)",
          "posicion": const GeoPoint(40.4250, -3.5350),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion": "Por parejas compartiendo 60 vidas. Muy divertido y colaborativo.",
        },
        {
          "id": "partida_mock_13",
          "titulo": "Draft Cubo Vintage",
          "formato": "Draft/Limited",
          "creadorUID": "mock_user_16",
          "creadorNombre": "Patricia Marín",
          "maxJugadores": 8,
          "jugadoresUIDs": ["mock_user_16", "mock_user_19", "mock_user_05"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 7))),
          "ubicacionNombre": "Espacio Joven (Alovera)",
          "posicion": const GeoPoint(40.5960, -3.2480),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion":
              "Cubo potenciado con cartas icónicas de toda la historia de MTG.",
        },
        {
          "id": "partida_mock_14",
          "titulo": "Pauper Friday Night",
          "formato": "Pauper",
          "creadorUID": "mock_user_14",
          "creadorNombre": "Nuria Gallego",
          "maxJugadores": 8,
          "jugadoresUIDs": ["mock_user_14", "mock_user_07"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 3, hours: 4)),
          ),
          "ubicacionNombre": "Centro Cultural La Estación (Meco)",
          "posicion": const GeoPoint(40.5520, -3.3280),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion":
              "Pauper accesible y dinámico. Barajas de préstamo disponibles.",
        },
        {
          "id": "partida_mock_15",
          "titulo": "Commander Playgroup Alcarria",
          "formato": "Commander",
          "creadorUID": "mock_user_20",
          "creadorNombre": "Tomás Aguilar",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_20"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 4, hours: 1)),
          ),
          "ubicacionNombre": "Cervecería El Rincón MTG (Guadalajara Centro)",
          "posicion": const GeoPoint(40.6320, -3.1650),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion":
              "Partidas distendidas mientras tomamos algo. Ambiente amigable.",
        },
        {
          "id": "partida_mock_16",
          "titulo": "Standard Showdown",
          "formato": "Standard",
          "creadorUID": "mock_user_17",
          "creadorNombre": "Quique Vidal",
          "maxJugadores": 8,
          "jugadoresUIDs": ["mock_user_17", "mock_user_09"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 5, hours: 3)),
          ),
          "ubicacionNombre": "Metrópolis Center (Madrid Callao)",
          "posicion": const GeoPoint(40.4195, -3.7065),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion": "Encuentro de Standard oficial con cartas de las últimas colecciones.",
        },
        {
          "id": "partida_mock_17",
          "titulo": "Commander Deckbuilding & Test",
          "formato": "Commander",
          "creadorUID": "mock_user_08",
          "creadorNombre": "Helena Ortiz",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_08", "mock_user_04"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 6, hours: 2)),
          ),
          "ubicacionNombre": "Biblioteca María Moliner (Coslada)",
          "posicion": const GeoPoint(40.4280, -3.5590),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion":
              "Trae tus barajas recién montadas para testear antes del torneo.",
        },
        {
          "id": "partida_mock_18",
          "titulo": "Pioneer Weekly Challenge",
          "formato": "Pioneer",
          "creadorUID": "mock_user_10",
          "creadorNombre": "Jorge Santos",
          "maxJugadores": 10,
          "jugadoresUIDs": ["mock_user_10", "mock_user_18"],
          "fechaHora": Timestamp.fromDate(
            ahora.add(const Duration(days: 7, hours: 1)),
          ),
          "ubicacionNombre": "Akira Comics (Madrid Barrio del Pilar)",
          "posicion": const GeoPoint(40.4780, -3.7080),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion": "Torneo regular de Pioneer en una de las mejores tiendas de Madrid.",
        },
        {
          "id": "partida_mock_19",
          "titulo": "Mesa Commander Casual Pod B",
          "formato": "Commander",
          "creadorUID": "mock_user_18",
          "creadorNombre": "Rocío Medina",
          "maxJugadores": 4,
          "jugadoresUIDs": ["mock_user_18", "mock_user_16"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 8))),
          "ubicacionNombre": "Club Social Cabanillas (Cabanillas del Campo)",
          "posicion": const GeoPoint(40.6380, -3.2340),
          "esTorneo": false,
          "estado": "abierta",
          "descripcion":
              "Commander distendido, barajas precon modificadas bienvenidas.",
        },
        {
          "id": "partida_mock_20",
          "titulo": "Torneo Premodern Fin de Mes",
          "formato": "Premodern",
          "creadorUID": "mock_user_12",
          "creadorNombre": "Lorena Campos",
          "maxJugadores": 16,
          "jugadoresUIDs": ["mock_user_12", "mock_user_13", "mock_user_03"],
          "fechaHora": Timestamp.fromDate(ahora.add(const Duration(days: 9))),
          "ubicacionNombre": "Ateneo Cultural Henares (Alcalá de Henares)",
          "posicion": const GeoPoint(40.4850, -3.3610),
          "esTorneo": true,
          "estado": "abierta",
          "descripcion":
              "Torneo especial de cierre de mes. Decklist requerida.",
        },
      ];

      for (final p in partidasMock) {
        final docRef = db.collection("Partidas").doc(p["id"] as String);
        batch.set(docRef, {
          "titulo": p["titulo"],
          "formato": p["formato"],
          "creadorUID": p["creadorUID"],
          "creadorNombre": p["creadorNombre"],
          "maxJugadores": p["maxJugadores"],
          "jugadoresUIDs": p["jugadoresUIDs"],
          "fechaHora": p["fechaHora"],
          "ubicacionNombre": p["ubicacionNombre"],
          "posicion": p["posicion"],
          "esTorneo": p["esTorneo"],
          "estado": p["estado"],
          "descripcion": p["descripcion"],
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint(
        "Sembradas ${partidasMock.length} mesas/torneos MTG de prueba.",
      );
      return partidasMock.length;
    } catch (e) {
      debugPrint("Error sembrando partidas de prueba: $e");
      return 0;
    }
  }

  /// Consulta puntual bajo demanda de partidas activas en Firestore (get puntual para coste 0)
  Future<List<Partida>> consultarPartidasActivas() async {
    try {
      final snapshot = await db
          .collection("Partidas")
          .withConverter<Partida>(
            fromFirestore: Partida.fromFirestore,
            toFirestore: (Partida p, _) => p.toFirestore(),
          )
          .where("estado", isEqualTo: "abierta")
          .get();

      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint("Error al consultar partidas: $e");
      return [];
    }
  }

  /// Limpia colecciones de prueba anteriores (mensajes huérfanos o pruebas pasadas)
  /// y vacía los avatares residuales en Storage para un reinicio limpio.
  Future<void> reiniciarDatosPrueba() async {
    try {
      await eliminarPerfilesSembrados();
      await sembrarPartidasPrueba();
      await StorageAdmin().vaciarAvataresStorage();
      debugPrint(
        "Colección Perfiles, Partidas y Storage reiniciados con éxito.",
      );
    } catch (e) {
      debugPrint("Aviso al reiniciar datos de prueba: $e");
    }
  }
}
