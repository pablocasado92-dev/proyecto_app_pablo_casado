// =====================================================================
// partida.dart — MODELO TIPADO DE MESA / TORNEO MTG (Colección "Partidas")
// ---------------------------------------------------------------------
// Representa una mesa de juego de Magic o torneo local:
//     Partidas/{partidaId}
// =====================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo fuertemente tipado para mesas de juego y torneos de Magic: The Gathering.
class Partida {
  /// Identificador único del documento en Firestore.
  final String id;

  /// Título o denominación del encuentro (ej. "Mesa Commander Casual 4P").
  final String titulo;

  /// Formato de MTG (Commander, Modern, Standard, Pioneer, Pauper, Draft, Premodern).
  final String formato;

  /// UID del usuario organizador o anfitrión.
  final String creadorUID;

  /// Nombre del organizador o anfitrión para renderizado rápido.
  final String creadorNombre;

  /// Capacidad máxima de jugadores (4 para Commander típico, 8 para Draft/Pod).
  final int maxJugadores;

  /// Lista de UIDs de los jugadores apuntados a la mesa.
  final List<String> jugadoresUIDs;

  /// Fecha y hora programada para la partida o torneo.
  final Timestamp fechaHora;

  /// Nombre o descripción del lugar (ej. "Tienda El Duende", "Parque Europa").
  final String ubicacionNombre;

  /// Coordenadas geográficas exactas de la mesa (GeoPoint).
  final GeoPoint posicion;

  /// Diferencia entre partida libre/casual (false) y evento/torneo competitivo (true).
  final bool esTorneo;

  /// Estado de la mesa: 'abierta', 'en_curso', 'finalizada', 'cancelada'.
  final String estado;

  /// Notas adicionales, restricciones de nivel de poder (Rule 0) o premios.
  final String? descripcion;

  const Partida({
    required this.id,
    required this.titulo,
    required this.formato,
    required this.creadorUID,
    required this.creadorNombre,
    required this.maxJugadores,
    required this.jugadoresUIDs,
    required this.fechaHora,
    required this.ubicacionNombre,
    required this.posicion,
    this.esTorneo = false,
    this.estado = 'abierta',
    this.descripcion,
  });

  /// Plazas libres restantes en la mesa.
  int get plazasLibres =>
      (maxJugadores - jugadoresUIDs.length).clamp(0, maxJugadores);

  /// Indica si la mesa ha alcanzado su cupo máximo de jugadores.
  bool get estaLlena => jugadoresUIDs.length >= maxJugadores;

  /// Conversor tipado (fromFirestore) para Firestore `.withConverter<Partida>`.
  factory Partida.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return Partida(
      id: snapshot.id,
      titulo: (data?['titulo'] as String?) ?? 'Partida MTG',
      formato: (data?['formato'] as String?) ?? 'Commander',
      creadorUID: (data?['creadorUID'] as String?) ?? '',
      creadorNombre: (data?['creadorNombre'] as String?) ?? 'Organizador',
      maxJugadores: (data?['maxJugadores'] as num?)?.toInt() ?? 4,
      jugadoresUIDs:
          (data?['jugadoresUIDs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      fechaHora: (data?['fechaHora'] as Timestamp?) ?? Timestamp.now(),
      ubicacionNombre:
          (data?['ubicacionNombre'] as String?) ?? 'Ubicación acordada',
      posicion:
          (data?['posicion'] as GeoPoint?) ?? const GeoPoint(40.4168, -3.7038),
      esTorneo: (data?['esTorneo'] as bool?) ?? false,
      estado: (data?['estado'] as String?) ?? 'abierta',
      descripcion: data?['descripcion'] as String?,
    );
  }

  /// Conversor tipado (toFirestore) para Firestore `.withConverter<Partida>`.
  Map<String, dynamic> toFirestore() {
    return {
      "titulo": titulo,
      "formato": formato,
      "creadorUID": creadorUID,
      "creadorNombre": creadorNombre,
      "maxJugadores": maxJugadores,
      "jugadoresUIDs": jugadoresUIDs,
      "fechaHora": fechaHora,
      "ubicacionNombre": ubicacionNombre,
      "posicion": posicion,
      "esTorneo": esTorneo,
      "estado": estado,
      if (descripcion != null) "descripcion": descripcion,
    };
  }
}
