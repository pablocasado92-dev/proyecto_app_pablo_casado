// =====================================================================
// perfil.dart — MODELO DEL PERFIL DEL USUARIO (Y SUS MENSAJES)
// ---------------------------------------------------------------------
// Representa un documento de la colección "Perfiles" de Firestore:
//     Perfiles/{uid}   ->  { name, edad, email, urlAvatar?, fechaRegistro }
// =====================================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import 'mensaje.dart';

/// Perfil del usuario logueado. Clase modelo (no es un widget).
class Perfil {
  /// Acceso a Cloud Firestore.
  var db = FirebaseFirestore.instance;

  /// Id del documento = uid del usuario en Firebase Auth.
  String uid = "";

  /// Nombre completo o apodo del usuario.
  String? name;

  /// Edad en años.
  int? edad;

  /// Correo electrónico del usuario.
  String? email;

  /// URL de descarga del avatar en Firebase Storage (opcional / null).
  String? urlAvatar;

  /// Fecha y hora de creación de la cuenta/perfil.
  Timestamp? fechaRegistro;

  /// Mensajes pertenecientes al usuario.
  List<Mensaje> mensajes = <Mensaje>[];

  /// Imagen mostrada en la vista si existe urlAvatar.
  Image? avatar;

  /// CALLBACK: se llama cuando cambian los mensajes en tiempo real.
  Function(int numeroMensajes)? onMessageReceived;

  /// Constructor con parámetros con nombre.
  Perfil({
    required this.uid,
    this.name,
    this.edad,
    this.email,
    this.urlAvatar,
    this.fechaRegistro,
  }) {
    if (urlAvatar != null && urlAvatar!.isNotEmpty) {
      avatar = Image.network(urlAvatar!);
    }
  }

  /// Registra la función que se llamará cuando cambien los mensajes.
  void setOnMessageReceived(Function(int numeroMensajes)? onMessageReceived) {
    this.onMessageReceived = onMessageReceived;
  }

  /// Constructor "factory" para LEER de Firestore.
  factory Perfil.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return Perfil(
      uid: snapshot.id,
      name: data?['name'] as String?,
      edad: (data?['edad'] as num?)?.toInt(),
      email: data?['email'] as String?,
      urlAvatar: data?['urlAvatar'] as String?,
      fechaRegistro: data?['fechaRegistro'] as Timestamp?,
    );
  }

  /// Conversión contraria: Perfil -> Map para guardarlo en Firestore con set().
  Map<String, dynamic> toFirestore() {
    return {
      if (name != null) "name": name,
      if (edad != null) "edad": edad,
      if (email != null) "email": email,
      "urlAvatar": urlAvatar, // Guarda la URL o null si no se ha subido foto aún
      if (fechaRegistro != null) "fechaRegistro": fechaRegistro,
    };
  }

  /// Empieza a escuchar EN TIEMPO REAL la colección principal "Mensajes" de Firestore.
  Future<void> descargarMensajes() async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    // Escucha en tiempo real los mensajes dirigidos a este usuario
    final queryDestinatario = db
        .collection("Mensajes")
        .where("destinatarioUID", isEqualTo: uid)
        .limit(20);

    queryDestinatario.snapshots().listen(
      (event) {
        mensajes.clear();
        for (var docSnapshot in event.docs) {
          Map<String, dynamic> fila = docSnapshot.data();
          mensajes.add(Mensaje(docSnapshot.id, fila));
        }
        onMessageReceived?.call(mensajes.length);
      },
      onError: (error) => debugPrint("Listen failed: $error"),
    );
  }

  /// Añade un mensaje nuevo a la lista local y a la colección "Mensajes" de Firestore.
  void agregarNuevoMensaje(Mensaje m) async {
    mensajes.add(m);
    await db.collection("Mensajes").add(m.toFirestore());
  }

  /// Marca como leídos los mensajes que no lo estaban y guarda cada cambio en Firestore.
  void marcarMensajesLeidos() async {
    for (Mensaje m in mensajes) {
      if (!m.leido) {
        m.leido = true;
        await m.update();
      }
    }
  }
}
