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

  /// Indicar si es el primer inicio de sesión del usuario (para mostrar el Onboarding)
  bool primerLogin = true;

  /// Mensajes pertenecientes a la conversación del usuario.
  List<Mensaje> mensajes = <Mensaje>[];

  /// Estado de carga de la suscripción de mensajes en Firestore.
  bool cargandoMensajes = false;

  /// Mensaje de error en caso de fallo al conectar con Firestore (null si no hay error).
  String? errorMensajes;

  /// BLOQUE 4: Suscripción activa al Stream de Firestore (tipada con Mensaje)
  /// Se guarda en una variable para poder cancelarla al cerrar sesión o destruir el perfil.
  StreamSubscription<QuerySnapshot<Mensaje>>? _messagesSubscription;

  /// Lista de oyentes/observadores de mensajes en tiempo real (Patrón Observer).
  final List<Function(int numeroMensajes)> _messageListeners = [];

  /// Constructor con parámetros con nombre.
  Perfil({
    required this.uid,
    this.name,
    this.edad,
    this.email,
    this.urlAvatar,
    this.fechaRegistro,
    this.primerLogin = true,
  });

  /// Registra una función callback (listener) cuando una pantalla entra en escena (initState).
  void addListener(Function(int numeroMensajes) listener) {
    if (!_messageListeners.contains(listener)) {
      _messageListeners.add(listener);
    }
  }

  /// BLOQUE 4: Elimina el listener de una pantalla cuando esta se destruye (dispose).
  void removeListener(Function(int numeroMensajes) listener) {
    _messageListeners.remove(listener);
  }

  /// Alias de compatibilidad
  void addOnMessageReceivedListener(Function(int numeroMensajes) listener) =>
      addListener(listener);

  void removeOnMessageReceivedListener(Function(int numeroMensajes) listener) =>
      removeListener(listener);

  /// Notifica a todas las pantallas suscritas activas cuando cambian los mensajes.
  void _notifyMessageListeners(int count) {
    for (final listener in List.of(_messageListeners)) {
      listener(count);
    }
  }

  /// Conversor tipado (fromFirestore): transforma el DocumentSnapshot de Firestore
  /// en un objeto fuertemente tipado de la clase [Perfil].
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
      primerLogin: (data?['primerLogin'] as bool?) ?? true,
    );
  }

  /// Conversor tipado (toFirestore): convierte la instancia [Perfil] a un Map para Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      if (name != null) "name": name,
      if (edad != null) "edad": edad,
      if (email != null) "email": email,
      "urlAvatar": urlAvatar,
      if (fechaRegistro != null) "fechaRegistro": fechaRegistro,
      "primerLogin": primerLogin,
    };
  }

  /// Escucha EN TIEMPO REAL la colección "Mensajes" de Firestore utilizando `.withConverter<Mensaje>`.
  /// Cancela cualquier suscripción previa para evitar fugas de memoria o escuchas duplicadas.
  Future<void> descargarMensajes() async {
    await _messagesSubscription?.cancel();

    final String authUid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    final String authEmail =
        FirebaseAuth.instance.currentUser?.email ?? email ?? "";

    final String myUidClean = authUid.trim().toLowerCase();
    final String userEmailClean = (email ?? authEmail).trim().toLowerCase();
    final String authEmailClean = authEmail.trim().toLowerCase();

    if (myUidClean.isEmpty && userEmailClean.isEmpty) return;

    cargandoMensajes = true;
    errorMensajes = null;
    _notifyMessageListeners(mensajes.length);

    // Consulta tipada con .withConverter<Mensaje> para recibir objetos Mensaje directamente
    final queryMensajes = db
        .collection("Mensajes")
        .withConverter<Mensaje>(
          fromFirestore: Mensaje.fromFirestore,
          toFirestore: (Mensaje m, _) => m.toFirestore(),
        )
        .limit(100);

    _messagesSubscription = queryMensajes.snapshots().listen(
      (event) {
        cargandoMensajes = false;
        errorMensajes = null;
        mensajes.clear();

        for (var docSnapshot in event.docs) {
          final Mensaje msg = docSnapshot.data();
          final String dest = (msg.destinatarioUID ?? "").trim().toLowerCase();
          final String rem = (msg.remitenteUID ?? "").trim().toLowerCase();

          // Filtrar mensajes enviados O recibidos por el usuario actual
          final bool esParaMi =
              (myUidClean.isNotEmpty && dest == myUidClean) ||
              (userEmailClean.isNotEmpty && dest == userEmailClean) ||
              (authEmailClean.isNotEmpty && dest == authEmailClean);

          final bool esDeMi =
              (myUidClean.isNotEmpty && rem == myUidClean) ||
              (userEmailClean.isNotEmpty && rem == userEmailClean) ||
              (authEmailClean.isNotEmpty && rem == authEmailClean);

          if (esParaMi || esDeMi) {
            mensajes.add(msg);
          }
        }

        // Ordenar cronológicamente por fecha
        mensajes.sort((a, b) {
          final aFecha =
              a.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bFecha =
              b.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aFecha.compareTo(bFecha);
        });

        _notifyMessageListeners(mensajes.length);
      },
      onError: (error) {
        cargandoMensajes = false;
        errorMensajes = "Error al cargar los mensajes: $error";
        debugPrint("Error escuchando mensajes: $error");
        _notifyMessageListeners(mensajes.length);
      },
    );
  }

  /// Añade un mensaje nuevo a Firestore utilizando el conversor tipado (`.withConverter<Mensaje>`).
  void agregarNuevoMensaje(Mensaje m) async {
    await db
        .collection("Mensajes")
        .withConverter<Mensaje>(
          fromFirestore: Mensaje.fromFirestore,
          toFirestore: (Mensaje msg, _) => msg.toFirestore(),
        )
        .add(m);
  }

  /// Marca como leídos los mensajes pendientes y guarda cada cambio en Firestore.
  void marcarMensajesLeidos() async {
    for (Mensaje m in mensajes) {
      if (!m.leido) {
        m.leido = true;
        await m.update();
      }
    }
  }

  /// BLOQUE 4: Cancela la suscripción activa de Firestore y limpia los listeners
  /// cuando el usuario cierra sesión o se destruye el perfil.
  void dispose() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _messageListeners.clear();
  }
}
