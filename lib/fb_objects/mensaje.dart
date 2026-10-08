// =====================================================================
// mensaje.dart — MODELO DE UN MENSAJE
// ---------------------------------------------------------------------
// Representa un documento de la SUBCOLECCIÓN de Firestore:
//     Perfiles/{uidPerfil}/Mensajes/{uidMensaje}
// con los campos titulo (String), cuerpo (String), leido (bool) y
// enviado (Timestamp).
// =====================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

/// Un mensaje del usuario. Es una clase de datos (modelo), no un widget.
class Mensaje {
  /// Acceso a Firestore para poder guardarse a sí mismo (ver update()).
  var db = FirebaseFirestore.instance;

  /// Id del documento en Firestore.
  String? uid;
  /// Título del mensaje.
  String? titulo;
  /// Texto completo del mensaje.
  String? cuerpo;
  /// Si el usuario ya lo ha visto.
  bool leido = false;
  /// Fecha y hora de envío.
  Timestamp? enviado;

  /// Constructor con nombre: crea un mensaje pasando todos los campos en orden.
  Mensaje.initCampos(this.uid, this.titulo, this.cuerpo, this.leido, this.enviado);

  /// Constructor principal: crea un Mensaje a partir del id del documento y del Map leído de Firestore.
  Mensaje(this.uid, Map<String, dynamic> fila) {
    titulo = fila["titulo"] as String? ?? "";
    cuerpo = fila["cuerpo"] as String? ?? "";
    leido = fila["leido"] as bool? ?? false;
    enviado = fila["enviado"] as Timestamp?;
  }

  /// Convierte el mensaje en un Map para guardarlo en Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      if (titulo != null) "titulo": titulo,
      if (cuerpo != null) "cuerpo": cuerpo,
      "leido": leido,
      if (enviado != null) "enviado": enviado,
    };
  }

  /// Guarda (sobrescribe) este mensaje en "Perfiles/{sPerfilUID}/Mensajes/{uid}".
  Future<void> update(String sPerfilUID) async {
    return await db.collection("Perfiles/$sPerfilUID/Mensajes").doc(uid).set(toFirestore());
  }
}
