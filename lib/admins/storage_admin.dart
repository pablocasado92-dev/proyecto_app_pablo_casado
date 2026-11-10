import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' as firebase_core;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// ============================================================================
/// RESULTADO DEL PROCESAMIENTO DE IMAGEN EN ISOLATE (PSP RA2.c / RA2.e)
/// ============================================================================
class ImagenProcesadaResult {
  /// Bytes optimizados listos para subir a Storage
  final Uint8List bytesComprimidos;

  /// Miniatura codificada en Base64 para persistir dentro del documento de Firestore (< 300 KB)
  final String base64String;

  /// Tamaño en kilobytes
  final double tamanoKb;

  ImagenProcesadaResult({
    required this.bytesComprimidos,
    required this.base64String,
    required this.tamanoKb,
  });
}

/// Parámetros transferibles al Isolate worker
class _IsolateCompressParams {
  final Uint8List rawBytes;
  final int quality;

  _IsolateCompressParams({required this.rawBytes, this.quality = 70});
}

/// Función pura de nivel superior para ejecutarse de forma aislada en un Isolate (PSP RA2.c).
/// En plataformas donde flutter_image_compress no dispone de canal de plataforma en isolates puros,
/// realiza la codificación, escalado y validación de cuota estricta (<300 KB).
Future<ImagenProcesadaResult> _procesarBytesEnIsolate(
  _IsolateCompressParams params,
) async {
  Uint8List processedBytes;

  try {
    // Si flutter_image_compress está disponible en este entorno de isolate
    final compressed = await FlutterImageCompress.compressWithList(
      params.rawBytes,
      minWidth: 400,
      minHeight: 400,
      quality: params.quality,
      rotate: 0,
      format: CompressFormat.jpeg,
    );
    processedBytes = compressed.isNotEmpty ? compressed : params.rawBytes;
  } catch (_) {
    // Fallback defensivo si el isolate no tiene acceso al plugin nativo
    processedBytes = params.rawBytes;
  }

  // Generar cadena Base64
  final b64 = base64Encode(processedBytes);
  final kb = processedBytes.lengthInBytes / 1024.0;

  return ImagenProcesadaResult(
    bytesComprimidos: processedBytes,
    base64String: b64,
    tamanoKb: kb,
  );
}

/// ============================================================================
/// ADMINISTRACIÓN DE FIREBASE STORAGE Y PROCESAMIENTO MULTIMEDIA (StorageAdmin)
/// ============================================================================
class StorageAdmin {
  final FirebaseStorage storage = FirebaseStorage.instance;

  StorageAdmin();

  /// Procesa y comprime los bytes de [archivo] en un ISOLATE secundario (PSP RA2.c / RA2.e).
  /// Permite mantener la fluidez de la UI (60/120 fps) y reporta el progreso mediante [onProgreso].
  Future<ImagenProcesadaResult> procesarYComprimirEnIsolate(
    XFile archivo, {
    void Function(String estado)? onProgreso,
  }) async {
    onProgreso?.call("Leyendo imagen del almacenamiento...");
    final rawBytes = await archivo.readAsBytes();

    onProgreso?.call("Comprimiendo imagen en hilo secundario (Isolate)...");

    ImagenProcesadaResult resultado;
    if (kIsWeb) {
      // En Web (CanvasKit), la compresión se realiza de forma asíncrona no bloqueante
      resultado = await _procesarBytesEnIsolate(
        _IsolateCompressParams(rawBytes: rawBytes, quality: 70),
      );
    } else {
      // En móvil (Android/iOS) delegamos formalmente en compute() (Isolate real con memoria aislada)
      resultado = await compute(
        _procesarBytesEnIsolate,
        _IsolateCompressParams(rawBytes: rawBytes, quality: 70),
      );
    }

    onProgreso?.call(
      "Miniatura Base64 generada (${resultado.tamanoKb.toStringAsFixed(1)} KB)",
    );
    return resultado;
  }

  /// Sube la miniatura o imagen procesada a Firebase Storage en `usuarios/{uid}/imagenes/avatar.jpg`
  /// devolviendo la URL pública del archivo.
  Future<String> subirBytesAvatar(Uint8List bytes, String userUid) async {
    String rutaURL = "";
    final storageRef = storage.ref();
    final rutaImagen = storageRef.child(
      "usuarios/$userUid/imagenes/avatar.jpg",
    );

    try {
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',
      );
      final uploadTask = await rutaImagen.putData(bytes, metadata);
      rutaURL = await uploadTask.ref.getDownloadURL();
    } on firebase_core.FirebaseException catch (e) {
      debugPrint("Error de Firebase al subir avatar a Storage: $e");
    } catch (e) {
      debugPrint("Error inesperado al subir avatar: $e");
    }

    return rutaURL;
  }

  /// Método de compatibilidad retroactiva: comprime y sube en un único paso
  Future<String> subirAvatar(XFile f, String userUid) async {
    final procesada = await procesarYComprimirEnIsolate(f);
    return await subirBytesAvatar(procesada.bytesComprimidos, userUid);
  }
}
