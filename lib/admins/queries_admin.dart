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

  /// Sembrado de partidas y mesas temáticas de MTG en tiendas y clubes locales
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
