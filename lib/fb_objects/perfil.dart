// =====================================================================
// perfil.dart — MODELO DEL PERFIL DEL USUARIO (Y SUS MENSAJES)
// ---------------------------------------------------------------------
// Representa un documento de la colección "Perfiles" de Firestore:
//     Perfiles/{uid}   ->  { name, edad, email, urlAvatar?, fechaRegistro }
// =====================================================================
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  /// Mensajes recibidos pertenecientes al usuario.
  List<Mensaje> mensajes = <Mensaje>[];

  /// Suscripción al Stream de Firestore para evitar listeners duplicados
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSubscription;

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
  });

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
      "urlAvatar": urlAvatar,
      if (fechaRegistro != null) "fechaRegistro": fechaRegistro,
    };
  }

  /// Empieza a escuchar EN TIEMPO REAL los MENSAJES RECIBIDOS del usuario desde Firestore.
  /// Cancela la suscripción anterior para evitar duplicaciones por múltiples escuchas.
  Future<void> descargarMensajes() async {
    await _messagesSubscription?.cancel();

    final String authUid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    final String authEmail = FirebaseAuth.instance.currentUser?.email ?? email ?? "";

    final String myUidClean = authUid.trim().toLowerCase();
    final String userEmailClean = (email ?? authEmail).trim().toLowerCase();
    final String authEmailClean = authEmail.trim().toLowerCase();

    if (myUidClean.isEmpty && userEmailClean.isEmpty) return;

    // Escuchar la colección principal "Mensajes" en tiempo real
    final queryMensajes = db.collection("Mensajes").limit(50);

    _messagesSubscription = queryMensajes.snapshots().listen(
      (event) {
        mensajes.clear();
        for (var docSnapshot in event.docs) {
          Map<String, dynamic> fila = docSnapshot.data();
          final String dest = (fila["destinatarioUID"] as String? ?? "").trim().toLowerCase();

          // Filtrar EXCLUSIVAMENTE los mensajes RECIBIDOS por este usuario (coincidencia por UID o Email)
          final bool esParaMi = (myUidClean.isNotEmpty && dest == myUidClean) ||
              (userEmailClean.isNotEmpty && dest == userEmailClean) ||
              (authEmailClean.isNotEmpty && dest == authEmailClean);

          if (esParaMi) {
            mensajes.add(Mensaje(docSnapshot.id, fila));
          }
        }
        onMessageReceived?.call(mensajes.length);
      },
      onError: (error) => debugPrint("Error escuchando mensajes: $error"),
    );
  }

  /// Añade un mensaje nuevo a Firestore.
  void agregarNuevoMensaje(Mensaje m) async {
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

  /// Libera la suscripción al cerrar sesión o destruir el perfil
  void dispose() {
    _messagesSubscription?.cancel();
  }
}
