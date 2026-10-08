import 'package:cloud_firestore/cloud_firestore.dart' as firebase_core;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// ============================================================================
/// ADMINISTRACIÓN DE FIREBASE STORAGE (StorageAdmin)
/// ============================================================================
/// Esta clase gestiona la subida, compresión y descarga de archivos/avatares
/// en Firebase Storage.
class StorageAdmin {
  final FirebaseStorage storage = FirebaseStorage.instance;

  StorageAdmin();

  /// Comprime la imagen [f], la sube a `usuarios/{uid}/imagenes/avatar.jpg` en Storage
  /// y devuelve su URL de descarga pública.
  Future<String> subirAvatar(XFile f, String userUid) async {
    String rutaURL = "";
    final storageRef = storage.ref();

    String ruta = "usuarios/$userUid/imagenes/avatar.jpg";
    final rutaImagen = storageRef.child(ruta);

    // Compresión de la imagen antes de subirla
    final result = await FlutterImageCompress.compressWithFile(
      f.path,
      minWidth: 2300,
      minHeight: 1500,
      quality: 35,
      rotate: 0,
    );

    try {
      if (result != null) {
        await rutaImagen.putData(result);
        rutaURL = await rutaImagen.getDownloadURL();
      }
    } on firebase_core.FirebaseException catch (e) {
      debugPrint("Error al subir avatar a Storage: $e");
    }

    return rutaURL;
  }
}
