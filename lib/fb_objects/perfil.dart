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

  /// Mensajes pertenecientes a la conversación del usuario.
  List<Mensaje> mensajes = <Mensaje>[];

  /// Suscripción al Stream de Firestore para evitar listeners duplicados
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;

  /// Lista de oyentes/observadores de mensajes en tiempo real
  final List<Function(int numeroMensajes)> _messageListeners = [];

  /// Constructor con parámetros con nombre.
  Perfil({
    required this.uid,
    this.name,
    this.edad,
    this.email,
    this.urlAvatar,
    this.fechaRegistro,
  });

  /// Añade un oyente de mensajes en tiempo real
  void addListener(Function(int numeroMensajes) listener) {
    if (!_messageListeners.contains(listener)) {
      _messageListeners.add(listener);
    }
  }

  /// Remueve un oyente específico al cerrar o destruir una pantalla
  void removeListener(Function(int numeroMensajes) listener) {
    _messageListeners.remove(listener);
  }

  /// Alias de compatibilidad
  void addOnMessageReceivedListener(Function(int numeroMensajes) listener) =>
      addListener(listener);

  void removeOnMessageReceivedListener(Function(int numeroMensajes) listener) =>
      removeListener(listener);

  /// Notifica a todos los oyentes activos (exactamente una vez por listener)
  void _notifyMessageListeners(int count) {
    for (final listener in List.of(_messageListeners)) {
      listener(count);
    }
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

  /// Empieza a escuchar EN TIEMPO REAL los MENSAJES de la conversación del usuario desde Firestore.
  /// Cancela la suscripción anterior para evitar duplicaciones por múltiples escuchas.
  Future<void> descargarMensajes() async {
    await _messagesSubscription?.cancel();

    final String authUid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    final String authEmail =
        FirebaseAuth.instance.currentUser?.email ?? email ?? "";

    final String myUidClean = authUid.trim().toLowerCase();
    final String userEmailClean = (email ?? authEmail).trim().toLowerCase();
    final String authEmailClean = authEmail.trim().toLowerCase();

    if (myUidClean.isEmpty && userEmailClean.isEmpty) return;

    // Escuchar la colección principal "Mensajes" en tiempo real
    final queryMensajes = db.collection("Mensajes").limit(100);

    _messagesSubscription = queryMensajes.snapshots().listen((event) {
      mensajes.clear();
      for (var docSnapshot in event.docs) {
        Map<String, dynamic> fila = docSnapshot.data();
        final String dest = (fila["destinatarioUID"] as String? ?? "")
            .trim()
            .toLowerCase();
        final String rem = (fila["remitenteUID"] as String? ?? "")
            .trim()
            .toLowerCase();

        // Filtrar mensajes enviados O recibidos por este usuario para construir la conversación del chat
        final bool esParaMi =
            (myUidClean.isNotEmpty && dest == myUidClean) ||
            (userEmailClean.isNotEmpty && dest == userEmailClean) ||
            (authEmailClean.isNotEmpty && dest == authEmailClean);

        final bool esDeMi =
            (myUidClean.isNotEmpty && rem == myUidClean) ||
            (userEmailClean.isNotEmpty && rem == userEmailClean) ||
            (authEmailClean.isNotEmpty && rem == authEmailClean);

        if (esParaMi || esDeMi) {
          mensajes.add(Mensaje(docSnapshot.id, fila));
        }
      }

      // Ordenar cronológicamente por fecha para el flujo de conversación del chat
      mensajes.sort((a, b) {
        final aFecha =
            a.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bFecha =
            b.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aFecha.compareTo(bFecha);
      });

      _notifyMessageListeners(mensajes.length);
    }, onError: (error) => debugPrint("Error escuchando mensajes: $error"));
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
    _messageListeners.clear();
  }
}
