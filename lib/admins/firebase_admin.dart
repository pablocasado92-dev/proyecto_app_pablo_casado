import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../fb_objects/perfil.dart';

/// Administrador central para las operaciones con Firebase (Firestore y Auth)
class FirebaseAdmin {
  FirebaseFirestore db = FirebaseFirestore.instance;
  FirebaseAuth fa = FirebaseAuth.instance;

  FirebaseAdmin();

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
}
