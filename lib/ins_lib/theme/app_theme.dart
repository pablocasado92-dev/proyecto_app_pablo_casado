import 'package:flutter/material.dart';

// =====================================================================
// AppTheme.dart — TOKENS DE DISEÑO (colores, espacios, radios y textos)
// ---------------------------------------------------------------------
// Clases con miembros static const que definen la paleta de colores,
// dimensiones y estilos de texto de la aplicación.
// =====================================================================

/// Paleta de colores de la aplicación
class AppColores {
  /// Verde de marca principal
  static const Color principal = Color.fromARGB(255, 146, 183, 123);

  /// Verde oscuro para iconos y textos destacados
  static const Color oscuro = Color.fromARGB(255, 70, 110, 60);

  /// Verde suave para fondos de etiquetas e iconos
  static const Color suave = Color.fromARGB(255, 226, 238, 218);

  /// Fondo general de las pantallas
  static const Color fondo = Color.fromARGB(255, 243, 246, 240);

  /// Fondo de tarjetas
  static const Color tarjeta = Colors.white;

  /// Texto principal
  static const Color texto = Color.fromARGB(255, 33, 37, 31);

  /// Texto secundario
  static const Color textoSecundario = Color.fromARGB(255, 104, 112, 100);

  /// Texto sobre fondo principal
  static const Color sobrePrincipal = Colors.white;

  /// Texto secundario sobre fondo principal
  static const Color sobrePrincipalSuave = Color.fromARGB(220, 255, 255, 255);

  /// Pastillas translúcidas sobre cabeceras
  static const Color pastilla = Color.fromARGB(56, 255, 255, 255);

  /// Líneas divisorias
  static const Color divisor = Color.fromARGB(255, 228, 233, 224);

  /// Borde de pastillas
  static const Color pastillaBorde = Color.fromARGB(110, 255, 255, 255);

  /// Borde de campos deshabilitados
  static const Color bordeCampo = Color.fromARGB(255, 205, 214, 199);

  /// Color de errores
  static const Color error = Color.fromARGB(255, 186, 26, 26);
}

/// Espaciados de la interfaz
class AppEspacios {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double anchoMaximo = 720;
  static const double anchoFormulario = 440;
  static const double alturaBoton = 48;
  static const double iconoGrande = 48;
  static const double imagenLista = 56;
}

/// Radios de curvatura de bordes
class AppRadios {
  static const double pastilla = 20;
  static const double tarjeta = 20;
  static const double cabecera = 32;
  static const double campo = 14;
  static const double imagen = 12;
}

/// Estilos tipográficos reutilizables
class AppTextos {
  static const TextStyle tituloCabecera = TextStyle(
    color: AppColores.sobrePrincipal,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    height: 1.25,
  );

  static const TextStyle etiqueta = TextStyle(
    color: AppColores.sobrePrincipal,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle fecha = TextStyle(
    color: AppColores.sobrePrincipalSuave,
    fontSize: 13,
  );

  static const TextStyle seccion = TextStyle(
    color: AppColores.oscuro,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle cuerpo = TextStyle(
    color: AppColores.texto,
    fontSize: 17,
    height: 1.6,
  );

  static const TextStyle tituloBarra = TextStyle(
    color: AppColores.sobrePrincipal,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle tituloPantalla = TextStyle(
    color: AppColores.oscuro,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle tituloLista = TextStyle(
    color: AppColores.texto,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle secundario = TextStyle(
    color: AppColores.textoSecundario,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle boton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

/// =====================================================================
/// Configuración unificada de ThemeData moderno para toda la aplicación
/// =====================================================================
class AppTheme {
  static ThemeData get tema {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColores.oscuro,
      primary: AppColores.oscuro,
      secondary: AppColores.principal,
      surface: AppColores.tarjeta,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColores.fondo,

      // Barra superior moderna y limpia
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColores.fondo,
        foregroundColor: AppColores.oscuro,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColores.oscuro),
        titleTextStyle: TextStyle(
          color: AppColores.oscuro,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),

      // Tarjetas con bordes redondeados y sombra sutil
      cardTheme: CardThemeData(
        color: AppColores.tarjeta,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
          side: const BorderSide(color: AppColores.divisor, width: 1),
        ),
      ),

      // Campos de texto modernos tipo cápsula rellena
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.divisor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.divisor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.oscuro, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadios.campo),
          borderSide: const BorderSide(color: AppColores.error, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColores.textoSecundario),
        prefixIconColor: AppColores.oscuro,
      ),

      // Botones elevados con altura confortable y esquinas redondeadas
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColores.oscuro,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, AppEspacios.alturaBoton),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadios.campo),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Botón flotante estilizado
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColores.oscuro,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Barra de navegación inferior
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 1,
        indicatorColor: AppColores.suave,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColores.oscuro,
            );
          }
          return const TextStyle(
            fontSize: 12,
            color: AppColores.textoSecundario,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColores.oscuro);
          }
          return const IconThemeData(color: AppColores.textoSecundario);
        }),
      ),

      // Diálogos redondeados
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        ),
      ),

      // Snackbars flotantes y suaves
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
