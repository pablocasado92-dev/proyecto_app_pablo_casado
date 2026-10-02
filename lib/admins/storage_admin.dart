import 'package:firebase_storage/firebase_storage.dart';

class Storageadmin {

  final storage = FirebaseStorage.instance;

  Storageadmin(){
    storage.useStorageEmulator("127.0.0.1", 9199);
  }



}