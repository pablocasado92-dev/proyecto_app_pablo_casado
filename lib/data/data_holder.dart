/// ============================================================================
/// BLOQUE 4: GESTIÓN DE DATOS COMPARTIDOS EN MEMORIA (DataHolder)
/// ============================================================================
/// La clase DataHolder utiliza el Patrón de Diseño SINGLETON.
/// Este patrón garantiza que solo exista una única instancia de la clase en toda
/// la aplicación, permitiendo compartir información entre diferentes pantallas
/// sin perder los datos al navegar.
class DataHolder {
  // 1. Variable estática que almacena la única instancia de la clase
  static final DataHolder _instance = DataHolder._internal();

  // 2. Constructor Factory: Devuelve siempre la misma instancia única (_instance)
  factory DataHolder() {
    return _instance;
  }

  // 3. Constructor privado nombrado: Impide crear nuevas instancias desde fuera
  DataHolder._internal();

  // ==========================================================================
  // VARIABLES GLOBALES (Almacenan la información del usuario en sesión)
  // ==========================================================================
  
  /// Correo electrónico del usuario autenticado
  String userEmail = '';

  /// Nombre completo del usuario
  String userName = '';

  // ==========================================================================
  // MÉTODOS ÚTILES
  // ==========================================================================

  /// Limpia los datos almacenados en el DataHolder (útil al cerrar sesión)
  void clearData() {
    userEmail = '';
    userName = '';
  }
}

/// Instancia global accesible en todo el proyecto
final DataHolder dataHolder = DataHolder();
