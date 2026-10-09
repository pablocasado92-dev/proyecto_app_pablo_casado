import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admins/device_admin.dart';
import '../admins/firebase_admin.dart';
import '../admins/storage_admin.dart';
import '../fb_objects/mensaje.dart';
import '../fb_objects/perfil.dart';

/// ============================================================================
/// ESTADO COMPARTIDO DE LA APLICACIÓN (DataHolder)
/// ============================================================================
/// Almacén global de datos de la app (patrón Singleton).
/// Mantiene en memoria el perfil del usuario, mensajes seleccionados,
/// administradores auxiliares y el estado de la barra de navegación.
class DataHolder {
  /// Instancias de administradores auxiliares (inicializados perezosamente)
  StorageAdmin? _storageAdmin;
  StorageAdmin get storageAdmin => _storageAdmin ??= StorageAdmin();

  FirebaseAdmin? _firebaseAdmin;
  FirebaseAdmin get firebaseAdmin => _firebaseAdmin ??= FirebaseAdmin();

  DeviceAdmin? deviceAdmin;

  /// Acceso a Cloud Firestore
  FirebaseFirestore? _db;
  FirebaseFirestore get db => _db ??= FirebaseFirestore.instance;

  /// Constructor privado para el patrón Singleton
  DataHolder._internal();

  /// Instancia única accesible globalmente
  static final DataHolder instance = DataHolder._internal();

  /// Factory constructor para poder instanciar con `DataHolder()` o `DataHolder.instance`
  factory DataHolder() => instance;

  // ==========================================================================
  // DATOS DEL USUARIO Y DE LA APLICACIÓN
  // ==========================================================================

  Perfil? _perfilUsuario;

  /// Perfil completo del usuario con sesión iniciada.
  Perfil get perfilUsuario => _perfilUsuario ??= Perfil(
        uid: FirebaseAuth.instance.currentUser?.uid ?? "",
        name: FirebaseAuth.instance.currentUser?.displayName ?? "Usuario",
      );

  set perfilUsuario(Perfil p) => _perfilUsuario = p;

  /// Mensaje actualmente seleccionado para ver en detalle
  Mensaje? mensajeSeleccionado;

  /// Variables de compatibilidad
  String userEmail = '';
  String userName = '';

  /// Caché en memoria para asociar UIDs con correos electrónicos
  final Map<String, String> _userEmailCache = {};

  /// Obtiene el correo electrónico asociado a un UID consultando la colección "Perfiles"
  Future<String> getEmailByUid(String? uid) async {
    if (uid == null || uid.isEmpty) return 'Anónimo';
    if (uid.contains('@')) return uid; // Si el campo ya contiene un correo directo

    if (_userEmailCache.containsKey(uid)) {
      return _userEmailCache[uid]!;
    }

    try {
      final doc = await db.collection("Perfiles").doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String emailEncontrado = (data['email'] as String? ?? '').isNotEmpty
            ? data['email'] as String
            : (data['name'] as String? ?? uid);
        _userEmailCache[uid] = emailEncontrado;
        return emailEncontrado;
      }
    } catch (e) {
      debugPrint("Error buscando email para $uid: $e");
    }

    _userEmailCache[uid] = uid;
    return uid;
  }

  // ==========================================================================
  // ESTADO COMPARTIDO DE LA BARRA INFERIOR (BottomBar Badges & Navigation)
  // ==========================================================================

  /// Indica si se muestra el punto en la pestaña de Notificaciones
  bool blNotificacionesBadge = true;

  /// Texto del número de mensajes no leídos para el badge
  String sMessagesBadgeText = "";

  /// Índice de la pestaña activa en la barra de navegación
  int iBotBarIndex = 0;

  /// Inicializa la instancia del DeviceAdmin con el contexto actual
  void initDeviceAdmin(BuildContext context) {
    deviceAdmin = DeviceAdmin(context);
  }

  /// Descarga el perfil del usuario en Firestore y actualiza los badges de mensajes
  Future<Perfil> descargarPerfil() async {
    perfilUsuario = await firebaseAdmin.descargarPerfil();

    int numNoLeido = 0;
    for (Mensaje m in perfilUsuario.mensajes) {
      if (!m.leido) numNoLeido++;
    }

    sMessagesBadgeText = numNoLeido > 0 ? numNoLeido.toString() : "";
    return perfilUsuario;
  }

  /// Limpia los datos de sesión almacenados
  void clearData() {
    userEmail = '';
    userName = '';
    _perfilUsuario = null;
    mensajeSeleccionado = null;
    sMessagesBadgeText = "";
    blNotificacionesBadge = true;
    iBotBarIndex = 0;
    _userEmailCache.clear();
  }
}

/// Instancia global accesible en todo el proyecto
final DataHolder dataHolder = DataHolder.instance;
