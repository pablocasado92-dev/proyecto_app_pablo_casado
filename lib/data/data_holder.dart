import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../admins/device_admin.dart';
import '../admins/firebase_admin.dart';
import '../admins/storage_admin.dart';
import '../fb_objects/mensaje.dart';
import '../fb_objects/perfil.dart';

/// ============================================================================
/// BLOQUE 4 / FASE 2: ESTADO COMPARTIDO DE LA APLICACIÓN (DataHolder)
/// ============================================================================
/// Almacén global de datos de la app (patrón Singleton).
/// Mantiene en memoria el perfil del usuario, mensajes seleccionados,
/// administradores auxiliares y el estado de la barra de navegación.
class DataHolder {
  /// Instancias de administradores auxiliares
  StorageAdmin storageAdmin = StorageAdmin();
  late DeviceAdmin deviceAdmin;
  FirebaseAdmin firebaseAdmin = FirebaseAdmin();

  /// Acceso a Cloud Firestore
  FirebaseFirestore db = FirebaseFirestore.instance;

  /// Constructor privado para el patrón Singleton
  DataHolder._internal();

  /// Instancia única accesible globalmente
  static final DataHolder instance = DataHolder._internal();

  /// Factory constructor para poder instanciar con `DataHolder()` o `DataHolder.instance`
  factory DataHolder() => instance;

  // ==========================================================================
  // DATOS DEL USUARIO Y DE LA APLICACIÓN
  // ==========================================================================

  /// Perfil completo del usuario con sesión iniciada
  late Perfil perfilUsuario;

  /// Mensaje actualmente seleccionado para ver en detalle
  Mensaje? mensajeSeleccionado;

  /// Variables heredadas de compatibilidad
  String userEmail = '';
  String userName = '';

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

    // Contar los mensajes no leídos para la insignia/badge de la barra
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
    mensajeSeleccionado = null;
    sMessagesBadgeText = "";
    blNotificacionesBadge = true;
    iBotBarIndex = 0;
  }
}

/// Instancia global accesible en todo el proyecto
final DataHolder dataHolder = DataHolder.instance;
