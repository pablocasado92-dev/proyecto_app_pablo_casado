import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admins/device_admin.dart';
import '../admins/firebase_admin.dart';
import '../admins/storage_admin.dart';
import '../fb_objects/conversacion.dart';
import '../fb_objects/mensaje.dart';
import '../fb_objects/perfil.dart';

export '../fb_objects/conversacion.dart';
export '../fb_objects/mensaje.dart';
export '../fb_objects/perfil.dart';

/// ============================================================================
/// ESTADO COMPARTIDO DE LA APLICACIÓN (DataHolder)
/// ============================================================================
/// Almacén global de datos de la app (patrón Singleton).
/// Mantiene en memoria el perfil del usuario, mensajes seleccionados,
/// contacto del chat activo, administradores auxiliares y estado de navegación.
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

  /// Perfil completo del usuario con sesión iniciada
  Perfil get perfilUsuario => _perfilUsuario ??= Perfil(
    uid: FirebaseAuth.instance.currentUser?.uid ?? "",
    name: FirebaseAuth.instance.currentUser?.displayName ?? "Usuario",
  );

  set perfilUsuario(Perfil p) => _perfilUsuario = p;

  /// Mensaje actualmente seleccionado
  Mensaje? mensajeSeleccionado;

  /// Contacto (UID o Email) con el que se está chateando en ChatScreen
  String? contactoChatSeleccionado;

  /// Variables de compatibilidad
  String userEmail = '';
  String userName = '';

  /// Cachés en memoria para no consultar Firestore repetidamente
  final Map<String, String> _userEmailCache = {};
  final Map<String, String> _userNameCache = {};

  /// Obtiene el correo electrónico asociado a un UID consultando la colección "Perfiles"
  Future<String> getEmailByUid(String? uid) async {
    if (uid == null || uid.isEmpty) return 'Anónimo';
    if (uid.contains('@')) {
      return uid; // Si el campo ya contiene un correo directo
    }

    if (_userEmailCache.containsKey(uid)) {
      return _userEmailCache[uid]!;
    }

    try {
      final doc = await db.collection("Perfiles").doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String emailEncontrado =
            (data['email'] as String? ?? '').isNotEmpty
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

  /// Obtiene el NOMBRE del usuario asociado a un UID o Email consultando la colección "Perfiles"
  Future<String> getNombreByUid(String? uid) async {
    if (uid == null || uid.isEmpty) return 'Anónimo';

    if (_userNameCache.containsKey(uid)) {
      return _userNameCache[uid]!;
    }

    try {
      if (uid.contains('@')) {
        // Buscar perfil por correo electrónico en Firestore
        final query = await db
            .collection("Perfiles")
            .where("email", isEqualTo: uid.trim().toLowerCase())
            .get();

        if (query.docs.isNotEmpty && query.docs.first.data()['name'] != null) {
          final String nombre = query.docs.first.data()['name'] as String;
          if (nombre.isNotEmpty) {
            _userNameCache[uid] = nombre;
            return nombre;
          }
        }
        _userNameCache[uid] = uid;
        return uid;
      }

      final doc = await db.collection("Perfiles").doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String nombreEncontrado =
            (data['name'] as String? ?? '').isNotEmpty
            ? data['name'] as String
            : (data['email'] as String? ?? uid);
        _userNameCache[uid] = nombreEncontrado;
        return nombreEncontrado;
      }
    } catch (e) {
      debugPrint("Error buscando nombre para $uid: $e");
    }

    _userNameCache[uid] = uid;
    return uid;
  }

  /// Agrupa la lista de mensajes en conversaciones individuales por contacto y las ordena por fecha más reciente
  List<Conversacion> getConversaciones() {
    final Map<String, List<Mensaje>> grupos = {};
    final String myUidClean = perfilUsuario.uid.trim().toLowerCase();
    final String myEmailClean =
        (FirebaseAuth.instance.currentUser?.email ?? userEmail)
            .trim()
            .toLowerCase();

    for (Mensaje m in perfilUsuario.mensajes) {
      final String rem = (m.remitenteUID ?? "").trim().toLowerCase();

      String contactoKey = "";
      if (rem == myUidClean ||
          (myEmailClean.isNotEmpty && rem == myEmailClean)) {
        contactoKey = m.destinatarioUID ?? "";
      } else {
        contactoKey = m.remitenteUID ?? "";
      }

      if (contactoKey.isEmpty) continue;

      if (!grupos.containsKey(contactoKey)) {
        grupos[contactoKey] = [];
      }
      grupos[contactoKey]!.add(m);
    }

    final List<Conversacion> lista = [];

    grupos.forEach((contactoKey, msgs) {
      msgs.sort((a, b) {
        final aF = a.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bF = b.fecha?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aF.compareTo(bF);
      });

      final int noLeidos = msgs.where((m) {
        if (m.leido) return false;
        final String dest = (m.destinatarioUID ?? "").trim().toLowerCase();
        final bool esParaMi =
            (myUidClean.isNotEmpty && dest == myUidClean) ||
            (myEmailClean.isNotEmpty && dest == myEmailClean);
        return esParaMi;
      }).length;

      lista.add(
        Conversacion(
          contactoUidOrEmail: contactoKey,
          ultimoMensaje: msgs.last,
          mensajesNoLeidos: noLeidos,
          mensajes: msgs,
        ),
      );
    });

    // Ordenar conversaciones cronológicamente: la que recibió/envió el mensaje más reciente aparece la primera
    lista.sort((a, b) {
      final aF =
          a.ultimoMensaje.fecha?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bF =
          b.ultimoMensaje.fecha?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bF.compareTo(aF); // Descendente (más reciente primero)
    });

    return lista;
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

  /// Indica si hay al menos un mensaje recibido sin leer en las conversaciones
  bool tieneMensajesSinLeer() {
    final String myUidClean = perfilUsuario.uid.trim().toLowerCase();
    final String myEmailClean =
        (FirebaseAuth.instance.currentUser?.email ?? userEmail)
            .trim()
            .toLowerCase();

    for (Mensaje m in perfilUsuario.mensajes) {
      if (!m.leido) {
        final String dest = (m.destinatarioUID ?? "").trim().toLowerCase();
        if ((myUidClean.isNotEmpty && dest == myUidClean) ||
            (myEmailClean.isNotEmpty && dest == myEmailClean)) {
          return true;
        }
      }
    }
    return false;
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
    contactoChatSeleccionado = null;
    sMessagesBadgeText = "";
    blNotificacionesBadge = true;
    iBotBarIndex = 0;
    _userEmailCache.clear();
    _userNameCache.clear();
  }
}

/// Instancia global accesible en todo el proyecto
final DataHolder dataHolder = DataHolder.instance;
