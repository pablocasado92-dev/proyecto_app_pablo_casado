import 'package:firebase_storage/firebase_storage.dart';

/// ============================================================================
/// ADMINISTRACIÓN DE FIREBASE STORAGE (StorageAdmin)
/// ============================================================================
/// Esta clase gestiona la conexión con Firebase Storage para la subida
/// y descarga de archivos de la aplicación.
class StorageAdmin {
  // Instancia de Firebase Storage
  final FirebaseStorage storage = FirebaseStorage.instance;

  /// Constructor de la clase
  /// Configura el emulador local de Firebase Storage para desarrollo
  StorageAdmin() {
    // Configura la conexión al emulador local en IP local y puerto 9199
    storage.useStorageEmulator("127.0.0.1", 9199);
  }
}
