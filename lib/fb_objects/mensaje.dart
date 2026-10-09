// =====================================================================
// mensaje.dart — MODELO DE UN MENSAJE
// ---------------------------------------------------------------------
// Representa un documento de la colección de Firestore "Mensajes":
//     Mensajes/{uidMensaje}   ->  { cuerpo, destinatarioUID, remitenteUID, fecha }
// =====================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

/// Un mensaje del usuario. Es una clase de datos (modelo), no un widget.
class Mensaje {
  /// Acceso a Firestore para poder guardarse a sí mismo (ver update()).
  var db = FirebaseFirestore.instance;

  /// Id del documento en Firestore.
  String? uid;

  /// Contenido principal del mensaje.
  String? cuerpo;

  /// UID del usuario destinatario.
  String? destinatarioUID;

  /// UID del usuario remitente.
  String? remitenteUID;

  /// Fecha y hora de envío del mensaje.
  Timestamp? fecha;

  /// Título opcional del mensaje (para encabezados de la lista).
  String? titulo;

  /// Estado de lectura del mensaje.
  bool leido = false;

  /// Constructor con campos iniciales
  Mensaje.initCampos(
    this.uid,
    this.cuerpo,
    this.destinatarioUID,
    this.remitenteUID,
    this.fecha, {
    this.titulo,
    this.leido = false,
  });

  /// Constructor a partir de un DocumentSnapshot/Map leído de Firestore.
  Mensaje(this.uid, Map<String, dynamic> fila) {
    cuerpo = fila["cuerpo"] as String? ?? "";
    destinatarioUID = fila["destinatarioUID"] as String? ?? "";
    remitenteUID = fila["remitenteUID"] as String? ?? "";
    fecha = (fila["fecha"] as Timestamp?) ?? (fila["enviado"] as Timestamp?);
    titulo = fila["titulo"] as String? ?? (cuerpo!.isNotEmpty ? cuerpo : "Mensaje");
    leido = fila["leido"] as bool? ?? false;
  }

  /// Convierte el mensaje en un Map para guardarlo en la colección "Mensajes" de Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      if (cuerpo != null) "cuerpo": cuerpo,
      if (destinatarioUID != null) "destinatarioUID": destinatarioUID,
      if (remitenteUID != null) "remitenteUID": remitenteUID,
      if (fecha != null) "fecha": fecha,
      "leido": leido,
      if (titulo != null) "titulo": titulo,
    };
  }

  /// Actualiza este documento en la colección principal "Mensajes" de Firestore.
  Future<void> update() async {
    if (uid != null && uid!.isNotEmpty) {
      await db.collection("Mensajes").doc(uid).set(toFirestore(), SetOptions(merge: true));
    }
  }
}
