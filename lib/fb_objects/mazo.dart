// =====================================================================
// mazo.dart — MODELO TIPADO DE BARAJA / DECK MTG (Colección "Mazos")
// ---------------------------------------------------------------------
// Representa una baraja de Magic: The Gathering:
//     Mazos/{mazoId}
// Compatible con formato texto plano (Moxfield / MTGGoldfish).
// =====================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo fuertemente tipado para las barajas de Magic de los usuarios.
class Mazo {
  /// Identificador único del documento en Firestore.
  final String id;

  /// UID del usuario propietario de la baraja.
  final String propietarioUID;

  /// Nombre asignado a la baraja (ej. "Atraxa Superfriends", "Mono Red Burn").
  final String titulo;

  /// Formato reglamentario de MTG (Commander, Modern, Standard, Pioneer, Pauper, etc.).
  final String formato;

  /// Nombre de la carta comandante (en caso de formatos Commander/Brawl/Oathbreaker).
  final String? comandante;

  /// Identidad de color de la baraja: lista de siglas MTG ('W', 'U', 'B', 'R', 'G', 'C').
  final List<String> colores;

  /// Lista de cartas en texto plano exportable e importable (formato Moxfield/MTGGoldfish):
  /// Ej:
  /// 1 Sol Ring
  /// 1 Command Tower
  /// 4 Lightning Bolt
  final String listaTexto;

  /// Número total de cartas contabilizadas en la baraja.
  final int numCartas;

  /// Si es pública para que otros duelistas de la comunidad puedan verla.
  final bool esPublico;

  /// Fecha de última modificación o guardado de la baraja.
  final Timestamp? fechaActualizacion;

  const Mazo({
    required this.id,
    required this.propietarioUID,
    required this.titulo,
    required this.formato,
    this.comandante,
    this.colores = const <String>[],
    this.listaTexto = '',
    this.numCartas = 0,
    this.esPublico = true,
    this.fechaActualizacion,
  });

  /// Cuenta las cartas a partir del texto plano si no se especificó numCartas
  static int contarCartasDeTexto(String texto) {
    if (texto.trim().isEmpty) return 0;
    int total = 0;
    final lineas = texto.split('\n');
    for (final l in lineas) {
      final lineaLimpia = l.trim();
      if (lineaLimpia.isEmpty ||
          lineaLimpia.startsWith('//') ||
          lineaLimpia.startsWith('#')) {
        continue;
      }
      final match = RegExp(r'^(\d+)\s+').firstMatch(lineaLimpia);
      if (match != null) {
        total += int.tryParse(match.group(1)!) ?? 1;
      } else {
        total += 1;
      }
    }
    return total;
  }

  /// Conversor tipado (fromFirestore) para `.withConverter<Mazo>`.
  factory Mazo.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    final texto = (data?['listaTexto'] as String?) ?? '';
    final count =
        (data?['numCartas'] as num?)?.toInt() ?? contarCartasDeTexto(texto);

    return Mazo(
      id: snapshot.id,
      propietarioUID: (data?['propietarioUID'] as String?) ?? '',
      titulo: (data?['titulo'] as String?) ?? 'Baraja sin título',
      formato: (data?['formato'] as String?) ?? 'Commander',
      comandante: data?['comandante'] as String?,
      colores:
          (data?['colores'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          const <String>[],
      listaTexto: texto,
      numCartas: count,
      esPublico: (data?['esPublico'] as bool?) ?? true,
      fechaActualizacion: data?['fechaActualizacion'] as Timestamp?,
    );
  }

  /// Conversor tipado (toFirestore) para `.withConverter<Mazo>`.
  Map<String, dynamic> toFirestore() {
    return {
      "propietarioUID": propietarioUID,
      "titulo": titulo,
      "formato": formato,
      if (comandante != null) "comandante": comandante,
      "colores": colores,
      "listaTexto": listaTexto,
      "numCartas": numCartas > 0 ? numCartas : contarCartasDeTexto(listaTexto),
      "esPublico": esPublico,
      "fechaActualizacion": fechaActualizacion ?? Timestamp.now(),
    };
  }
}
