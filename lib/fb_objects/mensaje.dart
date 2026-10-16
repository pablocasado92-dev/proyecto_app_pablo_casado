// =====================================================================
// mensaje.dart — MODELO DE DATOS DE UN MENSAJE (CON CONVERSOR TIPADO)
// ---------------------------------------------------------------------
// Representa un documento de la colección "Mensajes" en Cloud Firestore:
//   Mensajes/{uidMensaje} -> { cuerpo, destinatarioUID, remitenteUID, fecha, leido }
// Incluye los métodos fromFirestore y toFirestore para trabajar con
// conversión tipada (.withConverter<Mensaje>) en lugar de mapas sueltos.
// =====================================================================
import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase modelo que representa un mensaje individual de chat (no es un widget).
class Mensaje {
  /// Instancia de Cloud Firestore para operaciones de actualización directa.
  var db = FirebaseFirestore.instance;

  /// Identificador único (ID) del documento en la colección "Mensajes".
  String? uid;

  /// Contenido de texto del mensaje.
  String? cuerpo;

  /// UID o correo electrónico del usuario que recibe el mensaje.
  String? destinatarioUID;

  /// UID o correo electrónico del usuario que envía el mensaje.
  String? remitenteUID;

  /// Marca de tiempo (Timestamp) del envío del mensaje.
  Timestamp? fecha;

  /// Indica si el destinatario ya ha leído el mensaje.
  bool leido = false;

  /// Constructor para inicializar un mensaje nuevo en memoria antes de enviarlo.
  Mensaje.initCampos(
    this.uid,
    this.cuerpo,
    this.destinatarioUID,
    this.remitenteUID,
    this.fecha, {
    this.leido = false,
  });

  /// Constructor a partir de un ID y un mapa de datos de Firestore.
  Mensaje(this.uid, Map<String, dynamic> fila) {
    cuerpo = fila["cuerpo"] as String? ?? "";
    destinatarioUID = fila["destinatarioUID"] as String? ?? "";
    remitenteUID = fila["remitenteUID"] as String? ?? "";
    fecha = (fila["fecha"] as Timestamp?) ?? (fila["enviado"] as Timestamp?);
    leido = fila["leido"] as bool? ?? false;
  }

  /// Conversor tipado (fromFirestore): transforma un DocumentSnapshot de Firestore
  /// directamente en una instancia tipada de la clase [Mensaje].
  factory Mensaje.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return Mensaje(snapshot.id, data);
  }

  /// Conversor tipado (toFirestore): transforma el objeto [Mensaje] en un Map
  /// clave-valor listo para guardarse en Cloud Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      if (cuerpo != null) "cuerpo": cuerpo,
      if (destinatarioUID != null) "destinatarioUID": destinatarioUID,
      if (remitenteUID != null) "remitenteUID": remitenteUID,
      if (fecha != null) "fecha": fecha,
      "leido": leido,
    };
  }

  /// Actualiza este mensaje en Firestore utilizando conversión tipada (.withConverter).
  Future<void> update() async {
    if (uid != null && uid!.isNotEmpty) {
      final docRef = db
          .collection("Mensajes")
          .doc(uid)
          .withConverter<Mensaje>(
            fromFirestore: Mensaje.fromFirestore,
            toFirestore: (Mensaje m, _) => m.toFirestore(),
          );
      await docRef.set(this, SetOptions(merge: true));
    }
  }
}

