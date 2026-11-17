import 'mensaje.dart';

// =====================================================================
// conversacion.dart — MODELO DE UNA CONVERSACIÓN (HILO DE CHAT)
// ---------------------------------------------------------------------
// Agrupa los mensajes intercambiados con un contacto específico,
// calculando el último mensaje, los mensajes no leídos y la lista.
// =====================================================================
class Conversacion {
  /// Identificador opcional del hilo o documento en Firestore (si aplica)
  final String? id;

  /// Tipo de conversación: 'directo' (1 a 1) o 'grupo' (playgroup/mesa)
  final String tipo;

  /// Título opcional de la conversación (usado en grupos/mesas de MTG)
  final String? titulo;

  /// UID o Correo electrónico del contacto con el que se chatea (para hilos 1 a 1)
  final String contactoUidOrEmail;

  /// Participantes de la conversación (UIDs)
  final List<String> participantesUIDs;

  /// Creador de la conversación o mesa
  final String? creadorUID;

  /// Último mensaje enviado o recibido en esta conversación
  final Mensaje ultimoMensaje;

  /// Número de mensajes no leídos recibidos de este contacto
  final int mensajesNoLeidos;

  /// Lista completa de mensajes pertenecientes a esta conversación
  final List<Mensaje> mensajes;

  Conversacion({
    this.id,
    this.tipo = 'directo',
    this.titulo,
    required this.contactoUidOrEmail,
    this.participantesUIDs = const <String>[],
    this.creadorUID,
    required this.ultimoMensaje,
    required this.mensajesNoLeidos,
    required this.mensajes,
  });

  /// Indica si es un chat grupal o de mesa MTG
  bool get esGrupo => tipo == 'grupo' || tipo == 'partida';
}
