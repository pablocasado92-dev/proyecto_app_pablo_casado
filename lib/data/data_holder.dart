/// Clase DataHolder implementada mediante el patrón Singleton.
/// Permite almacenar y compartir datos globales entre diferentes pantallas 
/// de la aplicación sin perder la información al navegar.
class DataHolder {
  // Instancia única (Singleton)
  static final DataHolder _instance = DataHolder._internal();

  factory DataHolder() {
    return _instance;
  }

  DataHolder._internal();

  // --- Variables globales de la aplicación ---
  String userEmail = '';
  String userName = '';
  int counter = 0;
  
  // Método para reiniciar los datos si es necesario (ej. al cerrar sesión)
  void clearData() {
    userEmail = '';
    userName = '';
    counter = 0;
  }
}

// Instancia global accesible fácilmente en todo el proyecto
final DataHolder dataHolder = DataHolder();
