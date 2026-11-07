import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../fb_objects/perfil.dart';

/// ============================================================================
/// FIREBASE ADMIN (Servicio de autenticación y persistencia)
/// ============================================================================
/// Administrador central para las operaciones con Firebase (Firestore y Auth).
/// Gestiona la descarga de perfiles e inicio de sesión con Google (Bloque 1).
class FirebaseAdmin {
  FirebaseFirestore db = FirebaseFirestore.instance;
  FirebaseAuth fa = FirebaseAuth.instance;

  FirebaseAdmin();

  /// ==========================================================================
  /// BLOQUE 1: INICIO DE SESIÓN CON GOOGLE (Cross-Platform: Android + Web)
  /// ==========================================================================
  /// Inicia el flujo de autenticación de Google:
  /// - En Android/iOS: utiliza la librería nativa `google_sign_in`.
  /// - En Web: utiliza el popup nativo de `GoogleAuthProvider`.
  /// - Si el usuario cancela la selección de cuenta, retorna `null` de forma segura.
  /// - Si la autenticación tiene éxito, comprueba si el documento `Perfiles/{uid}`
  ///   existe en Cloud Firestore; si es nuevo, lo crea automáticamente.
  Future<UserCredential?> iniciarSesionConGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // En Web, Firebase Auth maneja el flujo de Google mediante un popup oficial
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        // prompt: select_account obliga a Google a mostrar siempre el selector de cuentas
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await fa.signInWithPopup(googleProvider);
      } else {
        // En Android / iOS: Flujo interactivo mediante GoogleSignIn
        final GoogleSignIn googleSignIn = GoogleSignIn();

        // Cerrar sesión previa en el cliente GoogleSignIn para obligar al sistema
        // a mostrar el selector de cuentas en lugar de auto-seleccionar la última
        try {
          await googleSignIn.signOut();
        } catch (e) {
          debugPrint("Aviso al limpiar sesión previa de GoogleSignIn: $e");
        }

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        // RF-04: Si el usuario canceló o cerró el diálogo sin seleccionar cuenta
        if (googleUser == null) {
          debugPrint("Google Sign-In: Cancelado por el usuario.");
          return null;
        }

        // Obtener los tokens de autenticación de la cuenta de Google
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Crear la credencial de Firebase a partir de los tokens de Google
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Iniciar sesión en Firebase Authentication
        userCredential = await fa.signInWithCredential(credential);
      }

      final User? user = userCredential.user;

      if (user != null) {
        // RF-05: Sincronizar documento en la colección "Perfiles/{uid}"
        final docRef = db
            .collection("Perfiles")
            .doc(user.uid)
            .withConverter(
              fromFirestore: Perfil.fromFirestore,
              toFirestore: (Perfil perfil, _) => perfil.toFirestore(),
            );

        final docSnap = await docRef.get();

        if (!docSnap.exists || docSnap.data() == null) {
          // Usuario nuevo: Inicializar perfil con los metadatos de Google
          final nuevoPerfil = Perfil(
            uid: user.uid,
            name:
                user.displayName ??
                (user.email != null ? user.email!.split('@')[0] : 'Usuario'),
            email: user.email ?? '',
            urlAvatar: user.photoURL,
            fechaRegistro: Timestamp.now(),
            primerLogin: false,
            conectado: true,
            ultimaConexion: Timestamp.now(),
          );
          await docRef.set(nuevoPerfil);
          debugPrint("Perfil de Google creado exitosamente para: ${user.uid}");
        } else {
          // Usuario recurrente: Actualizar estado de conexión
          await db.collection("Perfiles").doc(user.uid).update({
            'conectado': true,
            'ultimaConexion': FieldValue.serverTimestamp(),
          });
          debugPrint("Perfil de Google existente cargado para: ${user.uid}");
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Manejar cierres de popup en Web como cancelación limpia
      if (e.code == 'popup-closed-by-user' || e.code == 'canceled') {
        debugPrint("Google Sign-In cancelado por el usuario (popup cerrado).");
        return null;
      }
      debugPrint(
        "Error FirebaseAuthException en Google Sign-In: ${e.code} - ${e.message}",
      );
      rethrow;
    } catch (e) {
      debugPrint("Error general en Google Sign-In: $e");
      rethrow;
    }
  }

  /// Descarga el perfil del usuario actualmente autenticado desde la colección "Perfiles".
  Future<Perfil> descargarPerfil() async {
    Perfil? perfilTemp;

    if (fa.currentUser == null) {
      return Perfil(uid: "");
    }

    final docRef = db
        .collection("Perfiles")
        .doc(fa.currentUser!.uid)
        .withConverter(
          fromFirestore: Perfil.fromFirestore,
          toFirestore: (Perfil perfil, _) => perfil.toFirestore(),
        );

    final docSnap = await docRef.get();
    perfilTemp = docSnap.data();

    if (perfilTemp == null) {
      perfilTemp = Perfil(uid: fa.currentUser!.uid);
    } else {
      perfilTemp.descargarMensajes();
    }

    return perfilTemp;
  }

  /// Cierra la sesión activa de Google en el cliente nativo o web
  Future<void> cerrarSesionGoogle() async {
    if (!kIsWeb) {
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint("Error cerrando GoogleSignIn: $e");
      }
    }
  }
}
