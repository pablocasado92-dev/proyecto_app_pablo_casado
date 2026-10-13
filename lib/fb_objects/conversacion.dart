import 'mensaje.dart';

// =====================================================================
// conversacion.dart — MODELO DE UNA CONVERSACIÓN (HILO DE CHAT)
// ---------------------------------------------------------------------
// Agrupa los mensajes intercambiados con un contacto específico,
// calculando el último mensaje, los mensajes no leídos y la lista.
// =====================================================================
class Conversacion {
  /// UID o Correo electrónico del contacto con el que se chatea
  final String contactoUidOrEmail;

  /// Último mensaje enviado o recibido en esta conversación
  final Mensaje ultimoMensaje;

  /// Número de mensajes no leídos recibidos de este contacto
  final int mensajesNoLeidos;

  /// Lista completa de mensajes pertenecientes a esta conversación
  final List<Mensaje> mensajes;

  Conversacion({
    required this.contactoUidOrEmail,
    required this.ultimoMensaje,
    required this.mensajesNoLeidos,
    required this.mensajes,
  });
}
