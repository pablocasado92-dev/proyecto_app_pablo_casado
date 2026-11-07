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

  /// Comprime la imagen [f] y la sube a `usuarios/{uid}/imagenes/avatar.jpg` en Storage,
  /// devolviendo su URL de descarga pública.
  /// Compatible tanto con Android como con Flutter Web (lectura de bytes mediante XFile).
  Future<String> subirAvatar(XFile f, String userUid) async {
    String rutaURL = "";
    final storageRef = storage.ref();

    String ruta = "usuarios/$userUid/imagenes/avatar.jpg";
    final rutaImagen = storageRef.child(ruta);

    try {
      Uint8List bytesToUpload;

      if (kIsWeb) {
        // En Web leemos directamente los bytes del XFile
        bytesToUpload = await f.readAsBytes();
      } else {
        // En plataformas móviles comprimimos en segundo plano
        final compressed = await FlutterImageCompress.compressWithFile(
          f.path,
          minWidth: 800,
          minHeight: 800,
          quality: 75,
          rotate: 0,
        );
        bytesToUpload = compressed ?? await f.readAsBytes();
      }

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',
      );
      final uploadTask = await rutaImagen.putData(bytesToUpload, metadata);
      rutaURL = await uploadTask.ref.getDownloadURL();
    } on firebase_core.FirebaseException catch (e) {
      debugPrint("Error de Firebase al subir avatar a Storage: $e");
    } catch (e) {
      debugPrint("Error inesperado al subir avatar: $e");
    }

    return rutaURL;
  }
}
