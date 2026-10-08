// =====================================================================
// perfil.dart — MODELO DEL PERFIL DEL USUARIO (Y SUS MENSAJES)
// ---------------------------------------------------------------------
// Representa un documento de la colección "Perfiles" de Firestore:
//     Perfiles/{uid}   ->  { name, edad, altura, urlAvatar? }
// El id del documento es el uid del usuario en Firebase Auth: así cada
// cuenta tiene exactamente un perfil.
// Además, el perfil "es dueño" de la subcolección de mensajes:
//     Perfiles/{uid}/Mensajes/{idMensaje}
// que escucha en TIEMPO REAL (descargarMensajes) y, cuando cambia, avisa a
// la pantalla interesada mediante un CALLBACK (onMessageReceived).
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
  /// Nombre del usuario.
  String? name;
  /// Edad en años.
  int? edad;
  /// Altura (double: admite decimales).
  double? altura = 0.0;
  /// Mensajes de "Perfiles/{uid}/Mensajes". Los rellena descargarMensajes().
  List<Mensaje> mensajes = <Mensaje>[];
  /// Imagen mostrada en la vista: en memoria al elegirla o desde la URL
  /// guardada en Firestore al volver a cargar el perfil.
  Image? avatar;

  /// URL de descarga del avatar en Firebase Storage, persistida en Firestore.
  String? urlAvatar;

  /// CALLBACK: una función guardada en una variable. El perfil la llama cuando
  /// cambian los mensajes, pasando el número total.
  Function(int numeroMensajes)? onMessageReceived;

  /// Constructor con parámetros con nombre (y opcionales): Perfil(uid: ..., name: ...).
  Perfil({required this.uid, this.name, this.edad, this.altura, this.urlAvatar}) {
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
      altura: (data?['altura'] as num?)?.toDouble(),
      urlAvatar: data?['urlAvatar'] as String?,
    );
  }

  /// Conversión contraria: Perfil -> Map, para guardarlo con set().
  Map<String, dynamic> toFirestore() {
    return {
      if (name != null) "name": name,
      if (edad != null) "edad": edad,
      if (altura != null) "altura": altura,
      if (urlAvatar != null) "urlAvatar": urlAvatar,
    };
  }

  /// Empieza a escuchar EN TIEMPO REAL los mensajes del usuario (máximo 20)
  /// en "Perfiles/{uid}/Mensajes".
  Future<void> descargarMensajes() async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    final docRef = db.collection("Perfiles/$uid/Mensajes").limit(20);

    docRef.snapshots().listen(
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

  /// Añade un mensaje nuevo a la lista local y a Firestore.
  void agregarNuevoMensaje(Mensaje m) async {
    mensajes.add(m);
    final colMensajes = db.collection("Perfiles/$uid/Mensajes");
    await colMensajes.add(m.toFirestore());
  }

  /// Marca como leídos los mensajes que no lo estaban y guarda cada cambio en Firestore.
  void marcarMensajesLeidos() async {
    for (Mensaje m in mensajes) {
      if (!m.leido) {
        m.leido = true;
        await m.update(uid);
      }
    }
  }
}
